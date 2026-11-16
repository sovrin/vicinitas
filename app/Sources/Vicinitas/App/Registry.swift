import AppKit

/// Owns the routes: dev servers registered over the socket plus stored fixed routes.
/// Answers the CLI, keeps Caddy in sync and publishes the routes to the UI.
@MainActor
final class Registry: ObservableObject {
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var error: String?

    private let proxy: CaddyProxy
    private let server: SocketServer
    private let store: FixedRouteStore
    private var fixed: [Entry]
    private var live: [SocketServer.Client: Entry] = [:]
    /// Route pushes run one after another, so an older config can never land after a newer one.
    private var applying: Task<Void, Never>?

    init(
        proxy: CaddyProxy = CaddyProxy(),
        server: SocketServer = SocketServer(),
        store: FixedRouteStore = FixedRouteStore()
    ) {
        self.proxy = proxy
        self.server = server
        self.store = store
        fixed = store.load()
        entries = fixed.sorted { $0.name < $1.name }
        do {
            try proxy.start(with: entries) { [weak self] status in
                self?.error = "Caddy exited (status \(status)). Is port 80 in use?"
            }
        } catch {
            self.error = error.localizedDescription
        }

        server.onMessage = { [weak self] client, message in self?.handle(message, from: client) }
        server.onDisconnect = { [weak self] client in
            guard let self, live.removeValue(forKey: client) != nil else { return }
            publish()
        }
        server.onFailure = { [weak self] in self?.error = "Registration socket failed: \($0)" }
        do {
            try server.start()
        } catch {
            self.error = "Could not open the registration socket: \(error.localizedDescription)"
        }

        // Covers the Quit button, `quit app`, logout. A hard kill is handled by the pkill in CaddyProxy.start.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.server.stop()
                self?.proxy.stop()
            }
        }
    }

    /// Running app: ask its `vici` wrapper to Ctrl-C the dev server; the route goes when it disconnects.
    /// Fixed route: delete it.
    func stop(_ entry: Entry) {
        if entry.isFixed {
            fixed.removeAll { $0.name == entry.name }
            save()
            publish()
        } else if let client = live.first(where: { $0.value == entry })?.key {
            server.send(["op": "stop"], to: client)
        }
    }

    /// The CLI protocol. Returns nil for ok, or the error message for the client.
    private func handle(_ message: SocketServer.Message, from client: SocketServer.Client) -> String? {
        guard let name = message.name else { return "missing name" }
        let host = "\(name).localhost"
        let running = live.contains { $0.value.name == name && $0.key != client }
        let stored = fixed.first { $0.name == name }

        switch message.op {
        case "register":
            let entry = Entry(name: name, port: message.port ?? 0, cwd: message.cwd, isFixed: false)
            guard entry.isValid else { return "invalid name or port" }
            if let stored { return "\(host) is a fixed route to port \(stored.port), run: vici rm \(name)" }
            if running { return "\(host) is already running, pass --name" }
            live[client] = entry
        case "add":
            let entry = Entry(name: name, port: message.port ?? 0, cwd: nil, isFixed: true)
            guard entry.isValid else { return "invalid name or port" }
            if running { return "\(host) is running, stop it first" }
            fixed.removeAll { $0.name == name }
            fixed.append(entry)
            save()
        case "rm":
            if running { return "\(host) is a running app, stop it instead" }
            guard stored != nil else { return "no route named \(name)" }
            fixed.removeAll { $0.name == name }
            save()
        default:
            return "unknown op \(message.op)"
        }
        publish()
        return nil
    }

    private func save() {
        do {
            try store.save(fixed)
        } catch {
            self.error = "Could not save fixed routes: \(error.localizedDescription)"
        }
    }

    private func publish() {
        let all = (fixed + live.values).sorted { $0.name < $1.name }
        guard all != entries else { return }
        entries = all
        apply()
    }

    /// Pushes the current routes to Caddy.
    private func apply() {
        let entries = entries
        let previous = applying
        applying = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                try await proxy.apply(entries)
            } catch {
                self.error = "Could not update Caddy: \(error.localizedDescription)"
            }
        }
    }
}
