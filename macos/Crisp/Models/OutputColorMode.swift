import Foundation

/// Signal-format metadata supplied by CADisplay, not framebuffer depth or ICC profiles.
struct OutputColorMode: Identifiable, Equatable {
    let id: UInt64
    let width: Int
    let height: Int
    let refreshRate: Double
    let variable: Bool
    let depth: Int
    let color: String
    let hdr: String

    func sameTiming(as other: Self) -> Bool {
        width == other.width && height == other.height && variable == other.variable &&
        refreshRate.isFinite && other.refreshRate.isFinite && abs(refreshRate - other.refreshRate) < 0.01
    }
    var encoding: String {
        if color.contains("420") { return "YCbCr 4:2:0" }
        if color.contains("422") { return "YCbCr 4:2:2" }
        if color.contains("444") { return "YCbCr 4:4:4" }
        if color.contains("RGB") { return "RGB" }
        return color
    }
    var range: String {
        if color.contains("FullRange") { return "全范围" }
        if color.contains("LimitedRange") { return "有限范围" }
        return "范围未知"
    }
    var summary: String { "\(depth)-bit · \(encoding)" }
    var formatKey: String { "\(depth)|\(color)|\(hdr)" }
}
