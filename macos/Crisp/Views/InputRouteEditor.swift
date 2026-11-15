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
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 620),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "接线设置 — " + display.name
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 560, height: 600)
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
    @State private var suggestion: CustomInputSource?
    @State private var homeEdited = false
    @State private var automaticHome = false
    @State private var confirmedHome = false
    private let isFirstConfiguration: Bool

    init(display: DisplayInfo, close: @escaping () -> Void) {
        self.display = display
        self.close = close
        let route = InputSwitchService.shared.routes[display.displayUUID]
        isFirstConfiguration = route == nil
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
            endpoint("本机接口", name: Binding(get: { homeName }, set: {
                homeEdited = true; confirmedHome = false; homeName = $0
            }), value: Binding(get: { homeValue }, set: {
                homeEdited = true; confirmedHome = false; homeValue = $0
            }))
            endpoint("切换目标", name: $targetName, value: $targetValue)
            Text("接口菜单只预填实测的写入值；未验证的接口留空，需手动验证后填写。当前输入读回值不是切换写入值。自定义条目不代表已验证。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(reading ? "正在读取…" : "重新读取当前输入") {
                    Task { await readCurrent(prefill: false) }
                }.disabled(reading)
                if reading { ProgressView().controlSize(.small) }
            }
            if let readMessage { Text(readMessage).font(.caption).foregroundStyle(.secondary) }
            if let suggestion {
                Button("使用检测结果：\(suggestion.name)（写入 \(suggestion.value)）") {
                    applySuggestion(suggestion)
                }.disabled(reading)
            }
            if automaticHome {
                Toggle("我确认这台显示器当前显示的是此 Mac 的画面", isOn: $confirmedHome)
                    .font(.callout)
            }
            Text("保存只修改配置，不切屏。重新接线后请更新此设置。返回操作需要显示器仍接受本机接口上的 DDC 命令。")
                .font(.caption).foregroundStyle(.secondary)
            if duplicateValues {
                Text("本机和目标的写入值相同，会发送同一条命令。请核实未验证接口的写入值，不要直接填入当前读回编号。")
                    .font(.caption).foregroundStyle(.red)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Button("清除接线设置") { service.resetRoute(for: display.displayUUID); close() }
                Spacer()
                Button("取消", action: close).keyboardShortcut(.cancelAction)
                Button("保存") {
                    guard !automaticHome || confirmedHome else { return }
                    do {
                        try service.saveRoute(home: InputSourceDraft(name: homeName, number: homeValue),
                                              target: InputSourceDraft(name: targetName, number: targetValue),
                                              for: display.displayUUID)
                        close()
                    } catch { self.error = "请为本机和目标填写不同的接口名称及有效写入值（1–65535）。" }
                }.keyboardShortcut(.defaultAction).disabled(reading || duplicateValues || (automaticHome && !confirmedHome))
            }
        }
        .padding(22).frame(minWidth: 560, minHeight: 600)
        .task {
            if isFirstConfiguration { await readCurrent(prefill: true) }
        }
    }

    @MainActor
    private func readCurrent(prefill: Bool) async {
        guard !reading else { return }
        reading = true
        defer { reading = false }
        suggestion = nil
        await service.refreshInput(display)
        guard !Task.isCancelled else { return }
        guard let readback = service.macInput[display.displayUUID] else {
            readMessage = "读取失败，请确认显示器显示此 Mac 的画面后重试，或手动填写接线。"
            return
        }
        guard let detected = service.homeSuggestion(for: display, readback: readback) else {
            readMessage = "当前读回 \(readback)，尚无已验证的写入映射；不能将此读回编号直接填作写入值。"
            return
        }
        suggestion = detected
        readMessage = "检测到 \(detected.name)，读回 \(readback)，写入 \(detected.value)。请确认当前显示此 Mac 的画面；另一台设备的目标接口仍需指定。"
        if prefill && !homeEdited && homeName.isEmpty && homeValue.isEmpty
            && service.routes[display.displayUUID] == nil {
            applySuggestion(detected)
        }
    }

    private func applySuggestion(_ input: CustomInputSource) {
        homeName = input.name
        homeValue = String(input.value)
        automaticHome = true
        confirmedHome = false
    }

    private var duplicateValues: Bool {
        guard let home = InputSourceConfiguration.parseNumber(homeValue),
              let target = InputSourceConfiguration.parseNumber(targetValue) else { return false }
        return home == target
    }

    private func endpoint(_ title: String, name: Binding<String>, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            HStack {
                Menu("选择接口") {
                    ForEach(["DP1", "DP2", "HDMI1", "HDMI2", "USB-C"], id: \.self) { label in
                        Button(label) {
                            name.wrappedValue = label
                            value.wrappedValue = service.verifiedRouteValue(label, for: display).map { String($0) } ?? ""
                        }
                    }
                    if let custom = service.customInputs[display.displayUUID] {
                        Divider()
                        ForEach(custom) { input in
                            Button(input.name + "（自定义，需核实）") {
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
            if display.vendorNumber == 21063 && display.modelNumber == 10000,
               DDCInputSource.value(from: name.wrappedValue) == 18 {
                Text("HDMI2：Windows 当前接法已验证写入 17、读回 18；macOS 尚未验证。读回 18 不可直接当作写入值。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("填入 Windows 实测值 17（Mac 待验证）") {
                    value.wrappedValue = "17"
                }.font(.caption)
            }
        }
    }
}
