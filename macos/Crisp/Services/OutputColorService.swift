import AppKit
import Darwin

@MainActor
final class OutputColorService: ObservableObject {
    static let shared = OutputColorService()
    struct Snapshot {
        var current: OutputColorMode?
        var modes: [OutputColorMode] = []
        var otherTimingCount = 0
    }
    @Published private(set) var snapshots: [CGDirectDisplayID: Snapshot] = [:]
    @Published private(set) var errors: [CGDirectDisplayID: String] = [:]
    @Published private(set) var pendingDisplay: CGDirectDisplayID?
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var verified = false
    private var previous: CADisplayMode?
    private var pendingUUID: String?
    private var rollbackTask: Task<Void, Never>?
    private let framework = dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_LAZY)

    private func screen(_ id: CGDirectDisplayID) -> CADisplay? {
        guard framework != nil, let cls = NSClassFromString("CADisplay") as? CADisplay.Type,
              cls.responds(to: NSSelectorFromString("displays")) else { return nil }
        return cls.displays.first { $0.displayId == id && $0.responds(to: NSSelectorFromString("availableModes")) && $0.responds(to: NSSelectorFromString("setCurrentMode:")) && $0.responds(to: NSSelectorFromString("currentMode")) && $0.responds(to: NSSelectorFromString("update")) }
    }
    private func describe(_ m: CADisplayMode) -> OutputColorMode? {
        let selectors = ["width", "height", "bitDepth", "refreshRate", "colorMode", "hdrMode", "isVRR", "internalRepresentation"]
        guard selectors.allSatisfy({ m.responds(to: NSSelectorFromString($0)) }), m.width > 0, m.height > 0, m.bitDepth > 0, let color = m.colorMode, let hdr = m.hdrMode else { return nil }
        return OutputColorMode(id: m.internalRepresentation, width: Int(m.width), height: Int(m.height), refreshRate: m.refreshRate, variable: m.isVRR, depth: Int(m.bitDepth), color: color, hdr: hdr)
    }
    func reload(_ id: CGDirectDisplayID) {
        guard let d = screen(id) else { snapshots[id] = Snapshot(); return }
        d.update()
        guard let active = d.currentMode, let current = describe(active) else { snapshots[id] = Snapshot(); return }
        let all = (d.availableModes ?? []).compactMap(describe)
        var seen = Set<String>()
        var modes = all.filter { $0.sameTiming(as: current) && seen.insert($0.formatKey).inserted }
        // The active mode can be omitted by the available-mode list.
        if !modes.contains(where: { $0.formatKey == current.formatKey }) { modes.append(current) }
        modes.sort { a, b in
            if (a.hdr == "SDR") != (b.hdr == "SDR") { return a.hdr == "SDR" }
            if a.depth != b.depth { return a.depth > b.depth }
            return a.color < b.color
        }
        snapshots[id] = Snapshot(current: current, modes: modes,
            otherTimingCount: Set(all.filter { $0.width == current.width && $0.height == current.height && !$0.sameTiming(as: current) }.map(\.formatKey)).subtracting(Set(modes.map(\.formatKey))).count)
    }
    func apply(_ mode: OutputColorMode, to id: CGDirectDisplayID) async {
        guard pendingDisplay == nil, let d = screen(id), let uuid = DisplayInfo.cgDisplayUUID(id) else { return }
        d.update()
        guard let old = d.currentMode, let current = describe(old), mode.sameTiming(as: current), mode.formatKey != current.formatKey,
              let native = (d.availableModes ?? []).first(where: { $0.internalRepresentation == mode.id }) else {
            reload(id); return
        }
        errors[id] = nil
        previous = old; pendingUUID = uuid; pendingDisplay = id
        secondsRemaining = 15; verified = false
        // Arm recovery before requesting a signal change. Closing the panel does not cancel it.
        rollbackTask = Task { [weak self] in
            for remaining in stride(from: 14, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.pendingDisplay == id else { return }
                self.secondsRemaining = remaining
            }
            self?.revert()
        }
        d.currentMode = native
        try? await Task.sleep(for: .milliseconds(650))
        reload(id)
        guard pendingDisplay == id else { return }
        if let readback = snapshots[id]?.current, readback.formatKey == mode.formatKey, readback.sameTiming(as: mode) {
            verified = true
            return // The checkmark follows readback; user must keep the visible result.
        }
        revert()
        errors[id] = "系统未确认所选输出格式，已请求恢复原模式。"
    }
    func keep() {
        guard verified else { return }
        finish()
    }
    private func finish() {
        verified = false
        rollbackTask?.cancel(); rollbackTask = nil
        pendingDisplay = nil; pendingUUID = nil; previous = nil; secondsRemaining = 0
    }
    func revert() {
        guard let id = pendingDisplay else { return }
        if let old = previous, DisplayInfo.cgDisplayUUID(id) == pendingUUID, let d = screen(id) {
            d.update()
            if let original = (d.availableModes ?? []).first(where: { $0.internalRepresentation == old.internalRepresentation }) {
                d.currentMode = original
            } else { errors[id] = "原模式暂不可用，请在系统显示器设置中恢复。" }
        } else { errors[id] = "显示器已断开或连接已改变，无法恢复原模式。" }
        finish()
        Task { try? await Task.sleep(for: .milliseconds(650)); reload(id) }
    }
}
