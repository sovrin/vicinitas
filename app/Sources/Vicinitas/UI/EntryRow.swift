import AppKit
import SwiftUI

/// One route: host, project folder, and port. Click opens it; hover shows stop (running) or remove (fixed).
struct EntryRow: View {
    let entry: Entry
    let onStop: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: open) {
                HStack(spacing: 9) {
                    Group {
                        if entry.isFixed {
                            Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                        } else {
                            Circle().fill(.green).frame(width: 7, height: 7)
                        }
                    }
                    .frame(width: 19)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.host).lineLimit(1).truncationMode(.middle)
                        Text(entry.folder ?? "Fixed route")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    Spacer(minLength: 8)
                    Text(":\(String(entry.port))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .help("Open \(entry.host)")

            Button(action: onStop) {
                Image(systemName: entry.isFixed ? "xmark" : "stop.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color.primary.opacity(0.08), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .help(entry.isFixed ? "Remove route" : "Stop dev server")
            .opacity(hovering ? 1 : 0)
        }
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.07 : 0)))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contextMenu {
            Button("Open", action: open)
            Button("Copy Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("http://\(entry.host)", forType: .string)
            }
            if let cwd = entry.cwd {
                Button("Show in Finder") { NSWorkspace.shared.open(URL(fileURLWithPath: cwd)) }
            }
            Divider()
            Button(entry.isFixed ? "Remove Route" : "Stop", action: onStop)
        }
    }

    private func open() {
        if let url = entry.url { NSWorkspace.shared.open(url) }
    }
}
