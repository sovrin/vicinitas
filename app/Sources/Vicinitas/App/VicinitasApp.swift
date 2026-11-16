import SwiftUI

@main
struct VicinitasApp: App {
    @StateObject private var registry = Registry()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(registry: registry)
        } label: {
            Image(systemName: registry.error != nil ? "exclamationmark.triangle"
                : registry.entries.isEmpty ? "point.3.connected.trianglepath.dotted"
                : "point.3.filled.connected.trianglepath.dotted")
                .accessibilityLabel("vicinitas")
        }
        .menuBarExtraStyle(.window)
    }
}
