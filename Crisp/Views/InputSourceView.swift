import SwiftUI

struct InputHeadBlock: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject var state: PanelSectionState
    @ObservedObject private var service = InputSwitchService.shared

    var body: some View {
        if service.isAvailable(for: display) {
            ExpandableRow(
                icon: "arrow.left.arrow.right", iconActive: false,
                label: "Input Source", subtitle: String(localized: "Click to switch"),
                isExpanded: state.openBinding(\.inputOpenIDs, display.displayID)
            )
        }
    }
}

struct InputBodyBlock: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject var state: PanelSectionState
    @ObservedObject private var service = InputSwitchService.shared
    @State private var pending: UInt16?
    @State private var message: String?
    @State private var failed = false

    var body: some View {
        if service.isAvailable(for: display) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(1...2, id: \.self) { index in
                    if let value = service.resolve("dp\(index)", for: display) {
                        CheckmarkRow(
                            label: "DP\(index)",
                            isSelected: false, isPending: pending == value
                        ) { choose(value) }
                        .disabled(service.switching.contains(display.displayUUID))
                        .help(String(format: "VCP 0x60 · %d (0x%04X)", Int(value), Int(value)))
                    }
                }
                Text("Selecting an input sends its command immediately. The display stays connected to macOS.")
                    .inputCaption()
                Button("Customize Input Sources…") {
                    InputSourcesWindow.shared.show(for: display)
                }
                .buttonStyle(.link)
                .padding(.leading, 24)
                .padding(.vertical, 6)
                if let message {
                    Text(message).inputCaption()
                        .foregroundStyle(failed ? Color.red : Color.secondary)
                }
            }
        }
    }

    private func choose(_ value: UInt16) {
        guard pending == nil else { return }
        pending = value
        message = nil
        Task { @MainActor in
            let result = await service.switchInput(display, to: value)
            pending = nil
            switch result {
            case .failure(let error):
                failed = true
                message = error.description
            case .success:
                failed = false
                message = String(localized: "Command sent. Check the monitor to confirm the selected input.")
            }
        }
    }
}

private extension View {
    func inputCaption() -> some View {
        font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.vertical, 4)
    }
}
