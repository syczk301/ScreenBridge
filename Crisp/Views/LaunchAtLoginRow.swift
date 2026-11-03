import SwiftUI
import AppKit
import ServiceManagement

struct LaunchAtLoginRow: View {
    @State private var enabled = false
    @State private var needsApproval = false
    @State private var errorMessage: String?

    private func refresh() {
        enabled = LaunchService.shared.isEnabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
        SettingsService.shared.launchAtLogin = enabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(isOn: Binding(get: { enabled }, set: { wanted in
                let success = wanted ? LaunchService.shared.enable() : LaunchService.shared.disable()
                refresh()
                errorMessage = needsApproval || (success && enabled == wanted)
                    ? nil : "无法更新开机启动设置，请重试。"
            })) {
                HStack(spacing: 8) {
                    MenuItemIcon(systemName: "power", color: .green, active: enabled)
                        .accessibilityHidden(true)
                    Text("开机启动").font(.body)
                    Spacer()
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            Text("登录 macOS 后自动启动映桥")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.leading, 34)
            if needsApproval {
                Button("在系统设置中允许启动") { SMAppService.openSystemSettingsLoginItems() }
                    .buttonStyle(.link).font(.caption).padding(.leading, 34)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true).padding(.leading, 34)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 3)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .crispPanelDidOpen)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }
}
