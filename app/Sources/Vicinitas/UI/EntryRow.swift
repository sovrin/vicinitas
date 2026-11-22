import AppKit
import Paritas
import SwiftUI

/// One route: host, project folder, and port. Click opens it; hover shows stop (running) or remove (fixed).
struct EntryRow: View {
    let entry: Entry
    let onStop: () -> Void

    var body: some View {
        HoverRow(action: open) {
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
            RowBadge(":\(String(entry.port))")
        } actions: {
            RoundIconButton(systemImage: entry.isFixed ? "xmark" : "stop.fill",
                            help: entry.isFixed ? "Remove route" : "Stop dev server", action: onStop)
        }
        .help("Open \(entry.host)")
        .contextMenu {
            Button("Open", action: open)
            Button("Copy Link") { Pasteboard.copy("http://\(entry.host)") }
            if let cwd = entry.cwd {
                Button("Show in Finder") { showInFinder(URL(fileURLWithPath: cwd)) }
            }
            Divider()
            Button(entry.isFixed ? "Remove Route" : "Stop", action: onStop)
        }
    }

    private func open() {
        if let url = entry.url { NSWorkspace.shared.open(url) }
    }
}
