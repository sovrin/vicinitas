import Foundation

/// Everything Vicinitas keeps on disk, in one folder. The CLI hardcodes `socket` too.
enum AppPaths {
    static let support: URL = {
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Vicinitas")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let socket = support.appending(path: "vicinitas.sock")
    static let caddyConfig = support.appending(path: "caddy.json")
    static let fixedRoutes = support.appending(path: "fixed-routes.json")
}
