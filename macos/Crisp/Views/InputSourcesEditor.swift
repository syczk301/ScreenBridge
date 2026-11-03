import AppKit
import SwiftUI

/// A normal key window keeps text editing independent of the non-activating menu panel.
@MainActor
final class InputSourcesWindow {
    static let shared = InputSourcesWindow()
    private var windows: [String: NSWindow] = [:]

    func show(for display: DisplayInfo) {
        let uuid = display.displayUUID
        if let window = windows[uuid], window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let service = InputSwitchService.shared
        let drafts = service.options(for: display).map {
            InputSourceDraft(name: service.label(for: $0, display: display), number: String($0))
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = String(localized: "Customize Input Sources…") + " — " + display.name
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 520, height: 400)
        window.contentView = NSHostingView(rootView: InputSourcesEditor(
            displayName: display.name, uuid: uuid, initial: drafts,
            close: { [weak window] in window?.close() }
        ))
        windows[uuid] = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct InputSourcesEditor: View {
    let displayName: String
    let uuid: String
    let close: () -> Void
    @State private var rows: [InputSourceDraft]
    @State private var error: String?

    init(displayName: String, uuid: String, initial: [InputSourceDraft], close: @escaping () -> Void) {
        self.displayName = displayName
        self.uuid = uuid
        self.close = close
        _rows = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(displayName).font(.title2.bold())
            Text("Customize the commands shown for this display. Values use standard DDC input select (VCP 0x60).")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Text("Input name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Value (decimal / 0x hex)").frame(width: 180, alignment: .leading)
                Spacer().frame(width: 28)
            }.font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($rows) { $row in
                        HStack {
                            TextField("Input name", text: $row.name)
                                .textFieldStyle(.roundedBorder)
                            TextField("e.g. 17 or 0x11", text: $row.number)
                                .textFieldStyle(.roundedBorder).frame(width: 180)
                            Button {
                                rows.removeAll { $0.id == row.id }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Text("Remove input"))
                            .frame(width: 28)
                        }
                    }
                }
            }
            Button("Add Input") {
                rows.append(InputSourceDraft(name: "", number: ""))
                error = nil
            }
            Text("Saving only changes this list. It does not switch inputs. Port values depend on your monitor; LG alternate commands are not supported here.")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            Divider()
            HStack {
                Button("Restore Default Inputs") {
                    InputSwitchService.shared.resetCustom(for: uuid)
                    close()
                }
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        try InputSwitchService.shared.saveCustom(rows, for: uuid)
                        close()
                    } catch { self.error = error.localizedDescription }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 520, minHeight: 400)
    }
}
