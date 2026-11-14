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
                if let route = service.routes[display.displayUUID] {
                    Text("本机：\(route.home.name) · 目标：\(route.target.name)").inputCaption()
                    CheckmarkRow(label: "切到目标 · \(route.target.name)",
                                 isSelected: false, isPending: pending == route.target.value) {
                        choose(route.target.value)
                    }.disabled(service.switching.contains(display.displayUUID))
                    CheckmarkRow(label: "返回本机 · \(route.home.name)",
                                 isSelected: false, isPending: pending == route.home.value) {
                        choose(route.home.value)
                    }.disabled(service.switching.contains(display.displayUUID))
                } else {
                    Text("请按实际接线设置本机接口和切换目标。").inputCaption()
                }
                Button("接线设置…") { InputRouteWindow.shared.show(for: display) }
                    .buttonStyle(.link).padding(.leading, 24).padding(.vertical, 6)
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
