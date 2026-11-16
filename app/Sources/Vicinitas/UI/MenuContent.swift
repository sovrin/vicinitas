import AppKit
import SwiftUI

/// Menu bar panel (MenuBarExtra .window style), laid out like bivietas.
struct MenuContent: View {
    @ObservedObject var registry: Registry
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
            if let error = registry.error {
                warning(error)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            Divider().padding(.horizontal, 10)
            running
            Divider().padding(.horizontal, 10)
            footer.padding(5)
        }
        .frame(width: 340)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("vicinitas").font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 8)
        }
        .animation(.smooth(duration: 0.2), value: status)
    }

    private var status: String {
        if registry.error != nil { return "Not routing" }
        let count = registry.entries.count
        return "\(count) \(count == 1 ? "route" : "routes") · *.localhost"
    }

    private func warning(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text("Proxy not running").font(.callout.weight(.medium))
                Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Running

    private var running: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Routes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)
            if registry.entries.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "network").font(.title3).foregroundStyle(.tertiary)
                    Text("No apps running").font(.callout).foregroundStyle(.secondary)
                    Text("vici nuxt dev  ·  vici add api 8080")
                        .font(.caption.monospaced()).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                ForEach(registry.entries, id: \.self) { entry in
                    EntryRow(entry: entry) { registry.stop(entry) }
                        .padding(.horizontal, 5)
                }
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Launch at Login", systemImage: "sunrise")
                Spacer()
                Toggle("Launch at Login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            if let loginNote {
                Text(loginNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
            Button { NSApp.terminate(nil) } label: {
                HStack {
                    Label("Quit vicinitas", systemImage: "power")
                    Spacer()
                    Text("⌘Q").foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(HoverButtonStyle())
            .keyboardShortcut("q")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginNote = nil
        } catch {
            loginNote = error.localizedDescription
        }
        if LoginItem.needsApproval {
            loginNote = "Allow vicinitas in System Settings › General › Login Items."
        }
        launchAtLogin = LoginItem.isEnabled
    }
}
