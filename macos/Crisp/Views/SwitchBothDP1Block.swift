import SwiftUI

struct SwitchConfiguredInputsBlock: View {
    @EnvironmentObject var displayManager: DisplayManager
    @ObservedObject private var service = InputSwitchService.shared
    @State private var targetHovered = false
    @State private var homeHovered = false
    private var displays: [DisplayInfo] { service.physicalTargets(in: displayManager.displays) }
    private var unavailable: Bool {
        !displays.contains { service.routes[$0.displayUUID] != nil }
            || service.batchSwitching || displays.contains { service.switching.contains($0.displayUUID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("全部切到目标", destination: .target, hovered: $targetHovered)
            row("全部返回本机", destination: .home, hovered: $homeHovered)
            if let message = service.batchMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 46).padding(.trailing, 12).padding(.vertical, 3)
            }
        }
    }

    private func row(_ title: String, destination: DisplayInputRoute.Destination, hovered: Binding<Bool>) -> some View {
        Button {
            guard PanelOpenGuard.allowsActivation else { return }
            let snapshot = displayManager.displays
            Task { await service.switchConfigured(snapshot, to: destination) }
        } label: {
            HStack(spacing: 8) {
                MenuItemIcon(systemName: destination == .home ? "arrow.uturn.backward" : "arrow.left.arrow.right", active: false)
                    .accessibilityHidden(true)
                Text(title).font(.body)
                Spacer()
                if service.batchSwitching { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal, 12).padding(.vertical, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(unavailable)
        .menuRowHover(hovered.wrappedValue && !unavailable)
        .onHover { hovered.wrappedValue = $0 }
        .help("按每台显示器的接线设置发送；未配置的显示器会跳过。返回需原接口仍支持 DDC 通信。")
    }
}
