import Foundation
import CoreGraphics

/// Read each CGS table index directly. Duplicate mode ordering is not a VRR flag.
/// Signatures documented by AllRez/AppleMisc.h; optional lookup preserves compatibility.
enum DisplayRefreshMetadata {
    struct Value {
        let variable: Bool
        let proMotion: Bool
        let minimum: Double?
    }
    private typealias Flag = @convention(c) (UInt32, UInt32) -> Bool
    private typealias Minimum = @convention(c) (UInt32, UInt32, UnsafeMutablePointer<Float>) -> UInt32
    private static let variable: Flag? = symbol("SLSIsDisplayModeVRR", as: Flag.self)
    private static let proMotion: Flag? = symbol("SLSIsDisplayModeProMotion", as: Flag.self)
    private static let minimum: Minimum? = symbol("SLSGetDisplayModeMinRefreshRate", as: Minimum.self)
    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY), let address = dlsym(handle, name) else { return nil }
        return unsafeBitCast(address, to: type)
    }
    static func modes(for displayID: CGDirectDisplayID) -> [Int32: Value] {
        var count: Int32 = 0
        guard CGSGetNumberOfDisplayModes(displayID, &count) == .success, count > 0 else { return [:] }
        var result: [Int32: Value] = [:]
        for index in 0..<count {
            var description = CGSDisplayModeDescription()
            guard CGSGetDisplayModeDescriptionOfLength(displayID, index, &description,
                    Int32(MemoryLayout<CGSDisplayModeDescription>.size)) == .success else { continue }
            let isVariable = variable?(displayID, UInt32(index)) ?? false
            var floor: Float = 0
            let valid = minimum?(displayID, UInt32(index), &floor) == 0
            result[Int32(bitPattern: description.modeNumber)] = Value(
                variable: isVariable, proMotion: proMotion?(displayID, UInt32(index)) ?? false,
                minimum: isVariable && valid && floor.isFinite && floor > 0 ? Double(floor) : nil)
        }
        return result
    }
}
