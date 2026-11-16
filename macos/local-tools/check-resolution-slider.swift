@main struct ResolutionSliderChecks {
    static func main() {
        func eligible(_ w: Int, _ h: Int, _ hidpi: Bool = true) -> Bool {
            DisplayModeGeometry.isResolutionSliderEligible(width: w, height: h, isHiDPI: hidpi,
                nativeWidth: 3840, nativeHeight: 2160)
        }
        assert(eligible(1280, 720))
        assert(eligible(1600, 900))
        assert(eligible(1920, 1080))
        assert(eligible(2560, 1440))
        assert(eligible(3840, 2160, false))
        assert(!eligible(1920, 1080, false))
        assert(!eligible(640, 360))
        let stops = [(1280,720),(1600,900),(1920,1080),(2560,1440)]
            .filter { eligible($0.0, $0.1) }
        assert(stops.firstIndex { $0.0 == 1920 } == 2)
        print("PASS: 4K slider retains lower HiDPI stops; 1920x1080 is not the left endpoint")
    }
}
