import Foundation

/// Hardware-only mode never darkens the image through gamma, including old opt-ins.
/// Neutral reset and explicitly requested HDR boosting remain allowed.
enum SoftwareDimmingPolicy {
    static func permits(_ brightness: Double) -> Bool {
        brightness.isFinite && brightness >= 100
    }
}
