import Foundation
import CoreGraphics
import os.log

/// Direct DDC input commands. Reads and custom labels are optional metadata;
/// switching never requires a current input and never disconnects a display.
@MainActor
final class InputSwitchService: ObservableObject {
    static let shared = InputSwitchService()

    private static let log = Logger(subsystem: "com.crisp.app", category: "ddc")

    /// Inputs each monitor's capabilities string lists, by display uuid; empty when the
    /// string has no input entry. Read once per monitor: it takes 10 to 30 s on some.
    @Published private(set) var listed: [String: [UInt16]]
    /// Displays whose capabilities string is being read now.
    @Published private(set) var reading: Set<String> = []
    private var readTasks: [String: Task<Void, Never>] = [:]
    /// Only live readback, never a guessed current input or a persisted mark.
    @Published private(set) var macInput: [String: UInt16] = [:]
    @Published private(set) var customInputs: [String: [CustomInputSource]]
    @Published private(set) var routes: [String: DisplayInputRoute]
    @Published private(set) var switching: Set<String> = []
    @Published private(set) var batchSwitching = false
    @Published private(set) var batchMessage: String?

    func physicalTargets(in displays: [DisplayInfo]) -> [DisplayInfo] {
        var seen = Set<String>()
        return displays.filter { isAvailable(for: $0) && seen.insert($0.displayUUID).inserted }
    }

    /// Snapshot targets and launch every write before awaiting any result.
    func switchConfigured(_ displays: [DisplayInfo], to destination: DisplayInputRoute.Destination) async {
        let targets = physicalTargets(in: displays)
        guard !batchSwitching, !targets.isEmpty,
              targets.allSatisfy({ !switching.contains($0.displayUUID) }) else { return }
        batchSwitching = true
        batchMessage = nil
        defer { batchSwitching = false }
        let tasks = targets.map { display in
            let name = display.name
            let value = routes[display.displayUUID]?.input(for: destination).value
            return Task { @MainActor in
                guard let value else { return "\(name)：未设置接线，已跳过" }
                let result = await self.switchInput(display, to: value)
                switch result {
                case .success: return "\(name)：命令已发送"
                case .failure: return "\(name)：发送失败"
                }
            }
        }
        var messages: [String] = []
        for task in tasks { messages.append(await task.value) }
        batchMessage = messages.joined(separator: " · ")
    }

    func saveRoute(home: InputSourceDraft, target: InputSourceDraft, for uuid: String) throws {
        let route = try DisplayInputRoute.validated(home: home, target: target)
        var updated = routes
        updated[uuid] = route
        let data = try JSONEncoder().encode(updated)
        UserDefaults.standard.set(data, forKey: routeKey)
        routes = updated
    }

    func resetRoute(for uuid: String) {
        var updated = routes
        updated[uuid] = nil
        guard let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: routeKey)
        routes = updated
    }

    func switchRoute(_ display: DisplayInfo, to destination: DisplayInputRoute.Destination) async -> Result<Bool, SwitchError> {
        guard let value = routes[display.displayUUID]?.input(for: destination).value else {
            return .failure(.notConfigured)
        }
        return await switchInput(display, to: value)
    }

    private let routeKey = "screenbridge.DisplayInputRoutes.v1"
    private let listedKey = "crisp.InputSourcesListed"
    private let customKey = "screenbridge.CustomInputSources.v1"

    private init() {
        let defaults = UserDefaults.standard
        routes = (defaults.data(forKey: routeKey).flatMap {
            try? JSONDecoder().decode([String: DisplayInputRoute].self, from: $0)
        } ?? [:]).filter { $0.value.isValid }
        listed = Self.load(defaults.dictionary(forKey: listedKey))
        customInputs = defaults.data(forKey: customKey).flatMap {
            try? JSONDecoder().decode([String: [CustomInputSource]].self, from: $0)
        } ?? [:]
    }

    // MARK: - Queries

    func options(for display: DisplayInfo) -> [UInt16] {
        if let custom = customInputs[display.displayUUID] { return custom.map(\.value) }
        let values = listed[display.displayUUID].flatMap { $0.isEmpty ? nil : $0 } ?? DDCInputSource.standard
        return values.map { DDCInputSource.effectiveDP($0, vendor: display.vendorNumber, model: display.modelNumber) }
    }

    func label(for value: UInt16, display: DisplayInfo) -> String {
        customInputs[display.displayUUID]?.first { $0.value == value }?.name
            ?? DDCInputSource.dpLabel(value, vendor: display.vendorNumber, model: display.modelNumber)
            ?? DDCInputSource.name(for: value) ?? String(format: "Input 0x%02X", value)
    }

    /// Explicit numeric inputs remain literal; named DP inputs use the display profile.
    func resolve(_ text: String, for display: DisplayInfo) -> UInt16? {
        if let raw = InputSourceConfiguration.parseNumber(text) { return raw }
        if let custom = customInputs[display.displayUUID]?.first(where: {
            $0.name.caseInsensitiveCompare(text) == .orderedSame
        }) { return custom.value }
        guard let standard = DDCInputSource.value(from: text) else { return nil }
        // JU24F160L has different Set and Get VCP 0x60 mappings.
        // Verified physical DP1: write 18, read 15; DP2: write 15, read 16.
        // Keep advertised/readback values unchanged; map only named commands.
        // JU27F160L DP1 is independently verified; its DP2 remains unverified.
        if display.vendorNumber == 21063 && display.modelNumber == 9237 {
            if standard == 15 { return 18 }
            if standard == 16 { return 15 }
        }
        if display.vendorNumber == 21063 && display.modelNumber == 10000 && standard == 15 {
            return 18
        }
        return DDCInputSource.effectiveDP(standard, vendor: display.vendorNumber, model: display.modelNumber)
    }

    func saveCustom(_ drafts: [InputSourceDraft], for uuid: String) throws {
        let validated = try InputSourceConfiguration.validate(drafts)
        var updated = customInputs
        updated[uuid] = validated
        let data = try JSONEncoder().encode(updated)
        UserDefaults.standard.set(data, forKey: customKey)
        customInputs = updated
    }

    func resetCustom(for uuid: String) {
        var updated = customInputs
        updated[uuid] = nil
        guard let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: customKey)
        customInputs = updated
    }

    /// DDC reads may fail even on monitors that accept input writes. Keep the
    /// controls discoverable without requiring a successful probe.
    func isAvailable(for display: DisplayInfo) -> Bool {
        DDCInputSource.canOfferSwitching(
            isBuiltin: display.isBuiltin,
            isVirtual: VirtualDisplayService.shared.isVirtualDisplay(display.displayID)
                || MirroredModeService.isMirrorVirtual(display.displayID)
        )
    }

    // MARK: - Reads

    /// Reads the current input. A read that succeeds replaces a mark.
    func refreshInput(_ display: DisplayInfo) async {
        guard isAvailable(for: display) else { return }
        macInput[display.displayUUID] = await DDCService.shared.readInput(displayID: display.displayID)
    }

    /// Reads the capabilities string, once per monitor; started when the list is first
    /// opened, so a monitor nobody switches never sees the traffic. A second caller
    /// waits for the read already running.
    func readListIfNeeded(_ display: DisplayInfo) async {
        let uuid = display.displayUUID
        let displayID = display.displayID
        guard listed[uuid] == nil else { return }
        if let task = readTasks[uuid] { return await task.value }
        let task = Task {
            reading.insert(uuid)
            defer { reading.remove(uuid); readTasks[uuid] = nil }
            // A failed read is not stored, so the next opening tries again.
            guard let capabilities = await DDCService.shared.readCapabilities(displayID: displayID) else { return }
            let values = DDCInputSource.values(inCapabilities: capabilities) ?? []
            Self.log.notice("display \(displayID, privacy: .public) lists inputs \(values.map { String(format: "0x%02X", $0) }.joined(separator: " "), privacy: .public)")
            listed[uuid] = values
            save(listed, forKey: listedKey)
        }
        readTasks[uuid] = task
        await task.value
    }

    /// The final list and current input, for a caller that answers once (crispctl).
    func settle(_ display: DisplayInfo) async {
        await readListIfNeeded(display)
        await refreshInput(display)
    }

    // MARK: - Direct commands

    enum SwitchError: Error, CustomStringConvertible {
        case writeFailed, unavailable, busy, notConfigured
        var description: String {
            switch self {
            case .notConfigured: "请先设置此显示器的本机接口和切换目标。"
            case .writeFailed: String(localized: "Input switching failed. Enable DDC/CI in the monitor menu and check that the cable or dock supports DDC.")
            case .unavailable: String(localized: "Input switching is only available for physical external displays.")
            case .busy: String(localized: "An input command is already in progress.")
            }
        }
    }

    /// The result flag is false because direct input switching never disconnects
    /// the display from macOS. A successful transport write is not hardware readback.
    func switchInput(_ display: DisplayInfo, to value: UInt16) async -> Result<Bool, SwitchError> {
        guard isAvailable(for: display) else { return .failure(.unavailable) }
        let uuid = display.displayUUID
        guard !switching.contains(uuid) else { return .failure(.busy) }
        switching.insert(uuid)
        defer { switching.remove(uuid) }
        let written = await DirectInputCommand.send(value) { value in
            await DDCService.shared.writeInput(displayID: display.displayID, value: value)
        }
        guard written else { return .failure(.writeFailed) }
        macInput[uuid] = nil
        Self.log.notice("display \(display.displayID, privacy: .public) sent input \(value, privacy: .public); no disconnect")
        return .success(false)
    }

    /// Reconnect for the user's own Reconnect (row, crispctl, Shortcuts), which also
    /// switches a monitor that left through an input switch back to this Mac. The
    /// blackout rescue calls PhysicalDisplayToggleService.reconnect directly, so it
    /// never takes a monitor away from the other computer.
    @discardableResult
    func reconnect(uuid: String) async -> Result<Void, PhysicalDisplayToggleService.ToggleError> {
        let toggle = PhysicalDisplayToggleService.shared
        let returnInput = toggle.disconnected.first { $0.uuid == uuid }?.returnInput
        let result = await toggle.reconnect(uuid: uuid)
        guard case .success = result, let returnInput else { return result }
        // One write: the monitor re-links to this Mac (a 1.5 s hot plug drop) when it lands.
        guard let displayID = Self.onlineDisplayID(uuid: uuid) else { return result }
        let written = await DDCService.shared.writeInputAfterReconnect(displayID: displayID, value: returnInput)
        Self.log.notice("display \(uuid, privacy: .public) reconnected, input \(returnInput, privacy: .public) written: \(written, privacy: .public)")
        return result
    }

    // MARK: - Private

    private static func onlineDisplayID(uuid: String) -> CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.prefix(Int(count)).first { DisplayInfo.cgDisplayUUID($0) == uuid }
    }

    private func save(_ values: [String: [UInt16]], forKey key: String) {
        UserDefaults.standard.set(values.mapValues { $0.map(Int.init) }, forKey: key)
    }

    private static func load(_ stored: [String: Any]?) -> [String: [UInt16]] {
        (stored as? [String: [Int]] ?? [:]).mapValues { $0.compactMap(UInt16.init(exactly:)) }
    }
}
