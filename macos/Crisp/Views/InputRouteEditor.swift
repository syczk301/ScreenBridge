import AppKit
import SwiftUI

@MainActor
final class InputRouteWindow {
    static let shared = InputRouteWindow()
    private var windows: [String: NSWindow] = [:]

    func show(for display: DisplayInfo) {
        if let window = windows[display.displayUUID], window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 510),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "接线设置 — " + display.name
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 560, height: 490)
        window.contentView = NSHostingView(rootView: InputRouteEditor(display: display,
            close: { [weak window] in window?.close() }))
        windows[display.displayUUID] = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct InputRouteEditor: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject private var service = InputSwitchService.shared
    let close: () -> Void
    @State private var homeName: String
    @State private var homeValue: String
    @State private var targetName: String
    @State private var targetValue: String
    @State private var error: String?
    @State private var reading = false
    @State private var readMessage: String?

    init(display: DisplayInfo, close: @escaping () -> Void) {
        self.display = display
        self.close = close
        let route = InputSwitchService.shared.routes[display.displayUUID]
        _homeName = State(initialValue: route?.home.name ?? "")
        _homeValue = State(initialValue: route.map { String($0.home.value) } ?? "")
        _targetName = State(initialValue: route?.target.name ?? "")
        _targetValue = State(initialValue: route.map { String($0.target.value) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(display.name).font(.title2.bold())
            Text("按显示器一端的插口设置：本机接口用于返回这台 Mac，目标接口用于切换到另一台设备。")
                .font(.callout)
            endpoint("本机接口", name: $homeName, value: $homeValue)
            endpoint("切换目标", name: $targetName, value: $targetValue)
            Text("选择接口可预填型号映射或标准候选值。请核对实际插口及写入数值；JU27 的 DP2 尚未验证。名称和数值均可修改，保存后按此数值直接发送。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(reading ? "正在读取…" : "读取当前输入（仅供参考）") {
                    reading = true
                    Task { @MainActor in
                        await service.refreshInput(display)
                        if let value = service.macInput[display.displayUUID] {
                            readMessage = "当前读回：\(value)（" + String(format: "0x%02X", value) + "）。读回值不一定是写入值，也不代表本机接线。"
                        } else {
                            readMessage = "当前输入不可读，可按实际接线手动配置。"
                        }
                        reading = false
                    }
                }.disabled(reading)
                if reading { ProgressView().controlSize(.small) }
            }
            if let readMessage { Text(readMessage).font(.caption).foregroundStyle(.secondary) }
            Text("保存只修改配置，不切屏。重新接线后请更新此设置。返回操作需要显示器仍接受本机接口上的 DDC 命令。")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Button("清除接线设置") { service.resetRoute(for: display.displayUUID); close() }
                Spacer()
                Button("取消", action: close).keyboardShortcut(.cancelAction)
                Button("保存") {
                    do {
                        try service.saveRoute(home: InputSourceDraft(name: homeName, number: homeValue),
                                              target: InputSourceDraft(name: targetName, number: targetValue),
                                              for: display.displayUUID)
                        close()
                    } catch { self.error = "请为本机和目标填写不同的接口名称及有效写入值（1–65535）。" }
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22).frame(minWidth: 560, minHeight: 490)
    }

    private func endpoint(_ title: String, name: Binding<String>, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            HStack {
                Menu("选择接口") {
                    ForEach(["DP1", "DP2", "HDMI1", "HDMI2", "USB-C"], id: \.self) { label in
                        Button(label) {
                            name.wrappedValue = label
                            value.wrappedValue = service.resolve(label, for: display).map { String($0) } ?? ""
                        }
                    }
                    if let custom = service.customInputs[display.displayUUID] {
                        Divider()
                        ForEach(custom) { input in
                            Button(input.name) {
                                name.wrappedValue = input.name
                                value.wrappedValue = String(input.value)
                            }
                        }
                    }
                }.frame(width: 115)
                TextField("接口名称", text: name).textFieldStyle(.roundedBorder)
                TextField("写入值，如 18 / 0x12", text: value)
                    .textFieldStyle(.roundedBorder).frame(width: 175)
            }
        }
    }
}
