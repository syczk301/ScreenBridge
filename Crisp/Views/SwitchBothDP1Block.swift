import SwiftUI

struct SwitchBothDP1Block: View {
    @EnvironmentObject var displayManager: DisplayManager
    @ObservedObject private var service = InputSwitchService.shared
    @State private var isHovered = false
    private var pair: [DisplayInfo] { service.dp1Targets(in: displayManager.displays) }
    private var unavailable: Bool {
        pair.isEmpty || service.batchSwitching
            || pair.contains { service.switching.contains($0.displayUUID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                guard PanelOpenGuard.allowsActivation else { return }
                let displays = displayManager.displays
                Task { await service.switchBothToDP1(displays) }
            } label: {
                HStack(spacing: 8) {
                    MenuItemIcon(systemName: "arrow.left.arrow.right", active: false)
                        .accessibilityHidden(true)
                    Text(service.batchSwitching ? "正在切换…" : "全部切到 DP1")
                        .font(.body)
                    Spacer()
                    if service.batchSwitching { ProgressView().controlSize(.small) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(unavailable)
            .menuRowHover(isHovered && !unavailable)
            .onHover { isHovered = $0 }
            .help(!pair.isEmpty ? "将当前所有外接显示器切换到 DP1" : "需连接外接显示器")
            if let message = service.batchMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 46).padding(.trailing, 12)
                    .padding(.vertical, 3)
            }
        }
    }
}
