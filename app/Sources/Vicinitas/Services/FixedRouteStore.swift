import Foundation

/// Fixed routes (`vici add`), saved so they survive restarts.
struct FixedRouteStore {
    var url = AppPaths.fixedRoutes

    func load() -> [Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return ((try? JSONDecoder().decode([Entry].self, from: data)) ?? []).filter(\.isValid)
    }

    func save(_ entries: [Entry]) throws {
        try JSONEncoder().encode(entries).write(to: url, options: .atomic)
    }
}
