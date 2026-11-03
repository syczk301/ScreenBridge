// Test-only display/DDC substitutes. No hardware writes or display disconnects.
@_exported import Combine
import Foundation
import CoreGraphics

@MainActor final class DisplayInfo {
    var name: String { "Monitor \(displayID)" }
    let displayID: CGDirectDisplayID
    let displayUUID: String
    let isBuiltin: Bool
    let vendorNumber: UInt32
    let modelNumber: UInt32
    init(id: CGDirectDisplayID, builtin: Bool = false, vendor: UInt32 = 0, model: UInt32 = 0) {
        vendorNumber = vendor; modelNumber = model
        displayID = id; displayUUID = "test-monitor-\(id)"; isBuiltin = builtin
    }
    static func cgDisplayUUID(_ id: CGDirectDisplayID) -> String? { "test-monitor-\(id)" }
}
@MainActor final class DDCService {
    static let shared = DDCService()
    var writes: [(CGDirectDisplayID, UInt16)] = []
    var reads = 0
    var accept = true
    func readInput(displayID: CGDirectDisplayID) async -> UInt16? { reads += 1; return nil }
    func readCapabilities(displayID: CGDirectDisplayID) async -> String? { reads += 1; return nil }
    func writeInput(displayID: CGDirectDisplayID, value: UInt16) async -> Bool {
        writes.append((displayID,value)); return accept
    }
    func writeInputAfterReconnect(displayID: CGDirectDisplayID, value: UInt16) async -> Bool {
        await writeInput(displayID: displayID, value: value)
    }
}
@MainActor final class VirtualDisplayService {
    static let shared = VirtualDisplayService()
    func isVirtualDisplay(_ id: CGDirectDisplayID) -> Bool { id == 999 }
}
@MainActor enum MirroredModeService {
    static func isMirrorVirtual(_ id: CGDirectDisplayID) -> Bool { id == 998 }
}
@MainActor final class PhysicalDisplayToggleService {
    static let shared = PhysicalDisplayToggleService()
    enum ToggleError: Error { case unavailable }
    struct Record { let uuid: String; let returnInput: UInt16? }
    var disconnected: [Record] = []
    func reconnect(uuid: String) async -> Result<Void,ToggleError> { .success(()) }
}

/// Shadows Foundation.UserDefaults only in this isolated test executable.
/// Tests persistence calls without writing to the user's preferences.
@MainActor final class UserDefaults {
    static let standard = UserDefaults()
    private var values: [String: Any] = [:]
    func dictionary(forKey key: String) -> [String: Any]? { values[key] as? [String: Any] }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}
