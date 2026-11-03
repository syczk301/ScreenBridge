import Foundation

@main
struct HardwareScaleChecks {
    static func main() {
        assert(HardwareBrightnessScale.percent(current: 20, maximum: 100) == 20)
        assert(HardwareBrightnessScale.raw(percent: 20.7, maximum: 100) == 21)
        assert(HardwareBrightnessScale.percent(current: 51, maximum: 255) == 20)
        assert(HardwareBrightnessScale.raw(percent: 20, maximum: 255) == 51)
        assert(HardwareBrightnessScale.percent(current: 1, maximum: 0) == nil)
        assert(HardwareBrightnessScale.percent(current: 101, maximum: 100) == nil)
        for maximum: UInt16 in [100, 255, 65535] {
            for raw: UInt16 in [0, 1, maximum / 2, maximum] {
                let percent = HardwareBrightnessScale.percent(current: raw, maximum: maximum)!
                assert(HardwareBrightnessScale.raw(percent: percent, maximum: maximum) == raw)
            }
        }
        assert(HardwareBrightnessScale.raw(percent: -10, maximum: 100) == 0)
        assert(HardwareBrightnessScale.raw(percent: 150, maximum: 100) == 100)
        assert(HardwareBrightnessScale.raw(percent: .nan, maximum: 100) == 0)
        print("PASS: hardware 20/100 displays 20%, non-100 ranges round-trip, writes round to hardware steps, invalid reads rejected")
    }
}
