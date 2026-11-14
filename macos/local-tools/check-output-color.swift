import Foundation
@main struct OutputColorChecks {
    static func main() {
        func mode(_ rate: Double = 160, _ vrr: Bool = false, _ color: String = "RGBFullRange", _ width: Int = 3840) -> OutputColorMode {
            OutputColorMode(id: 1, width: width, height: 2160, refreshRate: rate, variable: vrr, depth: 10, color: color, hdr: "SDR")
        }
        precondition(mode().sameTiming(as: mode(160.0001)))
        precondition(!mode().sameTiming(as: mode(120)))
        precondition(!mode(60).sameTiming(as: mode(59.94)))
        precondition(!mode().sameTiming(as: mode(160, true)))
        precondition(!mode().sameTiming(as: mode(160, false, "RGBFullRange", 1920)))
        precondition(!mode(.nan).sameTiming(as: mode()))
        precondition(mode(160, false, "HDR10_422LimitedRange").encoding == "YCbCr 4:2:2")
        precondition(mode().range == "全范围")
        precondition(mode(160, false, "YCbCr444LimitedRange").range == "有限范围")
        precondition(mode(160, false, "unrecognized").range == "范围未知")
        print("Output color timing and format checks passed")
    }
}
