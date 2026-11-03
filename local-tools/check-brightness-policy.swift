import Foundation

@main
struct BrightnessPolicyChecks {
    static func main() {
        for value in [0.0, 15, 50, 85, 99.9] {
            assert(!SoftwareDimmingPolicy.permits(value))
        }
        assert(SoftwareDimmingPolicy.permits(100))
        assert(SoftwareDimmingPolicy.permits(150))
        assert(!SoftwareDimmingPolicy.permits(.nan))
        assert(!SoftwareDimmingPolicy.permits(.infinity))
        assert(CrispControlModel.brightnessBackend(isBuiltin: false, hdrSoftwareDimming: false,
            ddcAvailable: false, softwareDimmingAllowed: false) == .unavailable)
        assert(CrispControlModel.brightnessBackend(isBuiltin: false, hdrSoftwareDimming: false,
            ddcAvailable: false, softwareDimmingAllowed: true) == .software)
        assert(CrispControlModel.brightnessBackend(isBuiltin: false, hdrSoftwareDimming: true,
            ddcAvailable: true, softwareDimmingAllowed: false) == .unavailable)
        assert(CrispControlModel.brightnessBackend(isBuiltin: false, hdrSoftwareDimming: false,
            ddcAvailable: true, softwareDimmingAllowed: false) == .ddc)
        assert(CrispControlModel.brightnessBackend(isBuiltin: false, hdrSoftwareDimming: false,
            ddcAvailable: nil, softwareDimmingAllowed: false) == .unknown)
        assert(CrispControlModel.brightnessBackend(isBuiltin: true, hdrSoftwareDimming: false,
            ddcAvailable: nil, softwareDimmingAllowed: false) == .builtin)
        print("PASS: gamma dimming is disabled, neutral reset is allowed, unavailable DDC/HDR are not reported as software, hardware/system routes remain available")
    }
}
