import Foundation

/// One route: a dev server registered over the socket, or a fixed route (`vici add`).
struct Entry: Codable, Hashable {
    let name: String
    let port: Int
    let cwd: String?
    /// Fixed routes are stored and stay until removed; registered ones last as long as their connection.
    let isFixed: Bool

    var host: String { "\(name).localhost" }
    var url: URL? { URL(string: "http://\(host)") }
    /// Project folder with the home directory shortened to ~.
    var folder: String? {
        cwd.map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~", options: .anchored) }
    }

    /// Guards the trust boundary: name and port come from the socket and end up in Caddy's config.
    var isValid: Bool {
        name.range(of: "^[a-z0-9-]+(\\.[a-z0-9-]+)*$", options: .regularExpression) != nil
            && (1...65535).contains(port)
    }
}
