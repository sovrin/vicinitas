import Paritas
import SwiftUI

/// Menu bar panel, built from the shared Paritas components.
struct MenuContent: View {
    @ObservedObject var registry: Registry

    var body: some View {
        MenuPanel {
            PanelHeader("vicinitas", status: status,
                        icon: Image(systemName: "point.3.connected.trianglepath.dotted"), colors: [.teal, .blue])
            if let error = registry.error {
                WarningCard("Proxy not running", message: error)
            }
            PanelDivider()
            PanelSection("Routes") {
                if registry.entries.isEmpty {
                    EmptyState("No apps running", systemImage: "network",
                               hint: Text("vici nuxt dev  ·  vici add api 8080").monospaced())
                } else {
                    ForEach(registry.entries, id: \.self) { entry in
                        EntryRow(entry: entry) { registry.stop(entry) }
                            .padding(.horizontal, PanelMetrics.rowInset)
                    }
                }
            }
            PanelDivider()
            PanelFooter(appName: "vicinitas")
        }
    }

    private var status: String {
        if registry.error != nil { return "Not routing" }
        let count = registry.entries.count
        return "\(count) \(count == 1 ? "route" : "routes") · *.localhost"
    }
}
