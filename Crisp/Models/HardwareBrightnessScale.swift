import Foundation

/// Percent of the monitor's reported hardware range, never a combined software scale.
enum HardwareBrightnessScale {
    static func percent(current: UInt16, maximum: UInt16) -> Double? {
        guard maximum > 0, current <= maximum else { return nil }
        return Double(current) / Double(maximum) * 100
    }

    static func raw(percent: Double, maximum: UInt16) -> UInt16 {
        guard percent.isFinite, maximum > 0 else { return 0 }
        return UInt16((min(100, max(0, percent)) / 100 * Double(maximum)).rounded())
    }
}
