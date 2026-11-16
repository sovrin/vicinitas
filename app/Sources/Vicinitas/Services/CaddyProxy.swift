import Foundation

/// Owns the Caddy child process. Caddy boots from a config file; later route changes go through its admin API.
@MainActor
final class CaddyProxy {
    enum Failure: LocalizedError {
        case notInstalled
        case rejected(status: Int)

        var errorDescription: String? {
            switch self {
            case .notInstalled: "Caddy not found. Run: brew install caddy"
            case .rejected(let status): "Caddy rejected the new routes (HTTP \(status))."
            }
        }
    }

    /// Our own admin address, so we never clash with a Caddy the user runs themselves (default :2019).
    private static let admin = "localhost:2999"

    private let configURL: URL
    private var process: Process?

    init(configURL: URL = AppPaths.caddyConfig) {
        self.configURL = configURL
    }

    /// Starts Caddy on :80 serving `entries`. `onExit` fires only if Caddy dies on its own, not after `stop()`.
    func start(with entries: [Entry], onExit: @escaping @MainActor (Int32) -> Void) throws {
        guard let bin = ["/opt/homebrew/bin/caddy", "/usr/local/bin/caddy"]
            .first(where: FileManager.default.isExecutableFile)
        else { throw Failure.notInstalled }
        try Self.json(for: entries).write(to: configURL, options: .atomic)

        // A previous crash can leave our Caddy running and holding :80.
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-f", "caddy run --config \(configURL.path)"]
        try? pkill.run()
        pkill.waitUntilExit()

        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["run", "--config", configURL.path]
        p.terminationHandler = { [weak self] proc in
            let status = proc.terminationStatus
            Task { @MainActor [weak self] in
                guard let self, self.process != nil else { return }
                onExit(status)
            }
        }
        try p.run()
        process = p
    }

    /// Replaces the running config in one request; Caddy swaps it in without dropping connections.
    func apply(_ entries: [Entry]) async throws {
        var request = URLRequest(url: URL(string: "http://\(Self.admin)/load")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, from: Self.json(for: entries))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.rejected(status: status) }
    }

    func stop() {
        let p = process
        process = nil
        p?.terminate()
        p?.waitUntilExit()
    }

    private static func json(for entries: [Entry]) throws -> Data {
        try JSONSerialization.data(withJSONObject: config(for: entries), options: [.prettyPrinted, .sortedKeys])
    }

    static func config(for entries: [Entry]) -> [String: Any] {
        let routes: [[String: Any]] = entries.map { e in
            [
                "match": [["host": [e.host]]],
                // "localhost" lets Caddy reach servers bound to either 127.0.0.1 or ::1
                "handle": [["handler": "reverse_proxy", "upstreams": [["dial": "localhost:\(e.port)"]]]],
            ]
        }
        return [
            "admin": ["listen": admin],
            "apps": ["http": ["servers": ["vicinitas": [
                "listen": [":80"],
                "routes": routes,
                "automatic_https": ["disable": true],
            ]]]],
        ]
    }
}
