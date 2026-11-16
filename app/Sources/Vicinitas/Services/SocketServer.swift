import Foundation
import Network

/// Unix-socket server for the `vicinitas` CLI: newline-delimited JSON, one connection per client.
/// A registered dev server keeps its connection open; the kernel closes it when the process ends, however it ends.
@MainActor
final class SocketServer {
    struct Message: Decodable {
        let op: String
        let name: String?
        let port: Int?
        let cwd: String?
    }

    typealias Client = ObjectIdentifier

    /// Answers a message: nil means ok, a string is the error sent back to the client.
    var onMessage: ((Client, Message) -> String?)?
    var onDisconnect: ((Client) -> Void)?
    var onFailure: ((String) -> Void)?

    private static let maxLine = 16_384
    private let path: String
    private var listener: NWListener?
    private var clients: [Client: NWConnection] = [:]

    init(path: String = AppPaths.socket.path) {
        self.path = path
    }

    func start() throws {
        // Bind under a temporary name and rename once listening: the CLI reacts to the socket appearing,
        // and a rename is atomic, so the real path never exists without a listener behind it.
        let staging = path + ".starting"
        unlink(path) // stale socket from a previous run
        unlink(staging)
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: staging)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        listener.stateUpdateHandler = { [weak self, path] state in
            MainActor.assumeIsolated {
                switch state {
                case .ready:
                    if rename(staging, path) != 0 { self?.onFailure?(String(cString: strerror(errno))) }
                case .failed(let error):
                    self?.onFailure?(error.localizedDescription)
                default:
                    break
                }
            }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    func send(_ object: [String: Any], to client: Client) {
        guard let connection = clients[client],
              var data = try? JSONSerialization.data(withJSONObject: object)
        else { return }
        data.append(0x0A)
        connection.send(content: data, completion: .idempotent)
    }

    func stop() {
        listener?.cancel()
        clients.values.forEach { $0.cancel() }
        clients.removeAll()
        unlink(path)
    }

    private func accept(_ connection: NWConnection) {
        let client = Client(connection)
        clients[client] = connection
        connection.start(queue: .main)
        receive(on: connection, client, buffer: Data())
    }

    private func receive(on connection: NWConnection, _ client: Client, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxLine) { [weak self] data, _, done, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                var buffer = buffer + (data ?? Data())
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[buffer.startIndex..<newline]
                    buffer = Data(buffer[buffer.index(after: newline)...])
                    self.handle(line, from: client)
                }
                if done || error != nil || buffer.count > Self.maxLine {
                    self.drop(client)
                } else {
                    self.receive(on: connection, client, buffer: buffer)
                }
            }
        }
    }

    private func handle(_ line: Data, from client: Client) {
        guard let message = try? JSONDecoder().decode(Message.self, from: line) else {
            return send(["ok": false, "error": "bad request"], to: client)
        }
        let error = onMessage?(client, message)
        send(error.map { ["ok": false, "error": $0] } ?? ["ok": true], to: client)
    }

    private func drop(_ client: Client) {
        guard let connection = clients.removeValue(forKey: client) else { return }
        connection.cancel()
        onDisconnect?(client)
    }
}
