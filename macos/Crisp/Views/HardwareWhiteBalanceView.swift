import SwiftUI
import CoreGraphics

/// Hardware VCP gains, deliberately independent of GammaService and software dimming.
struct HardwareWhiteBalanceView: View {
    @ObservedObject var display: DisplayInfo
    let isExpanded: Bool
    @State private var values: [Double] = [0, 0, 0]
    @State private var maxima: [UInt16] = []
    @State private var baseline: [UInt16] = []
    @State private var busy = false
    @State private var message: String?
    private let codes: [UInt8] = [0x16, 0x18, 0x1A]
    private let names = ["R", "G", "B"]
    private let colors: [Color] = [.red, .green, .blue]
    private var storageKey: String { "screenbridge.hardwareRGB.baseline." + display.displayUUID }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("硬件白平衡（DDC）").font(.caption.bold())
                Spacer()
                if busy { ProgressView().controlSize(.small) }
            }
            if maxima.count == 3 {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text(names[index]).foregroundStyle(colors[index]).frame(width: 18)
                        Slider(value: Binding(get: { values[index] }, set: { values[index] = $0.rounded() }),
                               in: 0...Double(maxima[index])) { editing in
                            if !editing { let value = UInt16(values[index]); Task { await apply([(index, value)]) } }
                        }
                        .tint(colors[index])
                        Text("\(Int(values[index])) / \(maxima[index])")
                            .monospacedDigit().frame(width: 65, alignment: .trailing)
                    }
                    .disabled(busy)
                }
            }
            HStack {
                Button("读取硬件值") { Task { await refresh() } }
                Button("恢复首次记录值") {
                    let targets = Array(baseline.enumerated()).map { ($0.offset, $0.element) }
                    Task { await apply(targets) }
                }
                .disabled(baseline.count != 3 || maxima.count != 3)
            }
            .disabled(busy)
            Text("需在显示器菜单启用用户自定义色温。数值为硬件增益，不是软件百分比。")
                .foregroundStyle(.secondary)
            if baseline.count == 3 {
                Text("首次记录：R \(baseline[0]) · G \(baseline[1]) · B \(baseline[2])")
                    .foregroundStyle(.secondary)
            }
            if let message { Text(message).foregroundStyle(.secondary) }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .task(id: isExpanded) { if isExpanded { await refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .crispPanelDidOpen)) { _ in
            if isExpanded { Task { await refresh() } }
        }
    }

    private func matches(_ id: CGDirectDisplayID, _ uuid: String) -> Bool {
        guard CGDisplayIsOnline(id) != 0,
              let actual = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return false }
        return (CFUUIDCreateString(nil, actual) as String).caseInsensitiveCompare(uuid) == .orderedSame
    }

    private func read(_ id: CGDirectDisplayID, _ code: UInt8) async -> (current: UInt16, max: UInt16)? {
        await withCheckedContinuation { continuation in
            DDCService.shared.readAsync(displayID: id, command: code, forceRefresh: true) {
                continuation.resume(returning: $0)
            }
        }
    }

    /// Two fresh matching reads. The DDC service also validates the VCP echo and checksum.
    private func snapshot(_ id: CGDirectDisplayID, _ uuid: String) async -> [(current: UInt16, max: UInt16)]? {
        var result: [(current: UInt16, max: UInt16)] = []
        for code in codes {
            guard matches(id, uuid), let a = await read(id, code), a.max > 0, a.current <= a.max else { return nil }
            try? await Task.sleep(for: .milliseconds(150))
            guard matches(id, uuid), let b = await read(id, code), a.current == b.current, a.max == b.max else { return nil }
            result.append(b)
        }
        return result
    }

    private func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let id = display.displayID, uuid = display.displayUUID
        guard let result = await snapshot(id, uuid), matches(id, uuid) else {
            maxima = []; message = "暂时无法可靠读取硬件 RGB；请确认 DDC/CI 已开启后重试。"; return
        }
        values = result.map { Double($0.current) }; maxima = result.map(\.max)
        let saved = UserDefaults.standard.array(forKey: storageKey) as? [Int]
        if let saved, saved.count == 3, saved.enumerated().allSatisfy({ $0.element >= 0 && $0.element <= Int(maxima[$0.offset]) }) {
            baseline = saved.map { UInt16($0) }
        } else {
            baseline = result.map(\.current)
            UserDefaults.standard.set(baseline.map(Int.init), forKey: storageKey)
        }
        message = "已读取显示器硬件值"
    }

    private func apply(_ targets: [(Int, UInt16)]) async {
        guard !busy, maxima.count == 3, !targets.isEmpty else { return }
        busy = true
        defer { busy = false }
        let id = display.displayID, uuid = display.displayUUID
        for (index, value) in targets {
            guard codes.indices.contains(index), value <= maxima[index], matches(id, uuid) else {
                maxima = []; message = "显示器连接已变化，请重新读取。"; return
            }
            let ok = await withCheckedContinuation { continuation in
                DDCService.shared.writeAsync(displayID: id, command: codes[index], value: value) {
                    continuation.resume(returning: $0)
                }
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard ok, matches(id, uuid), let result = await snapshot(id, uuid) else {
                maxima = []; message = "未能确认硬件写入，请重新读取；已停止后续写入。"; return
            }
            values = result.map { Double($0.current) }; maxima = result.map(\.max)
            guard result[index].current == value else {
                message = "显示器未采用请求值，已显示实际读回值。请检查用户自定义色温。"; return
            }
        }
        message = "已写入并回读确认"
    }
}
