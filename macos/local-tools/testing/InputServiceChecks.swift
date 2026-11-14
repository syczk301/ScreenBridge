import Foundation

@main
struct InputServiceChecks {
    @MainActor static func main() async throws {
        let key = "screenbridge.CustomInputSources.v1"
        let persisted = ["test-monitor-123": [CustomInputSource(name: "Saved PC", value: 17)]]
        UserDefaults.standard.set(try JSONEncoder().encode(persisted), forKey: key)
        let savedRoute = DisplayInputRoute(home: CustomInputSource(name: "USB-C", value: 27),
                                          target: CustomInputSource(name: "HDMI1", value: 17))
        UserDefaults.standard.set(try JSONEncoder().encode(["test-monitor-700": savedRoute]), forKey: "screenbridge.DisplayInputRoutes.v1")
        let service = InputSwitchService.shared
        let ddc = DDCService.shared
        let display = DisplayInfo(id: 123)
        assert(service.options(for: display) == [17])
        assert(service.label(for: 17, display: display) == "Saved PC")
        try service.saveCustom([InputSourceDraft(name: "Work Mac", number: "0x0F")], for: display.displayUUID)
        let stored = try JSONDecoder().decode([String: [CustomInputSource]].self,
            from: UserDefaults.standard.data(forKey: key)!)
        assert(stored[display.displayUUID] == [CustomInputSource(name: "Work Mac", value: 15)])
        assert(service.options(for: DisplayInfo(id: 456)) == DDCInputSource.standard)
        do {
            try service.saveCustom([InputSourceDraft(name: "Bad", number: "0")], for: display.displayUUID)
            fatalError("Invalid save succeeded")
        } catch is InputSourceConfiguration.ValidationError { }
        assert(service.options(for: display) == [15] && ddc.writes.isEmpty)
        service.resetCustom(for: display.displayUUID)
        assert(service.options(for: display) == DDCInputSource.standard)
        assert(service.macInput[display.displayUUID] == nil)
        let first = await service.switchInput(display, to: 17)
        guard case .success(false) = first else { fatalError("Unknown current input blocked a direct write") }
        let repeated = await service.switchInput(display, to: 17)
        guard case .success(false) = repeated else { fatalError("Repeated input was not sent") }
        assert(ddc.writes.count == 2 && ddc.writes.allSatisfy { $0.0 == 123 && $0.1 == 17 })
        assert(ddc.reads == 0)
        assert(service.macInput[display.displayUUID] == nil)
        ddc.accept = false
        let failed = await service.switchInput(display, to: 15)
        guard case .failure(.writeFailed) = failed else { fatalError("Write failure was lost") }
        for invalid in [DisplayInfo(id: 1,builtin: true),DisplayInfo(id: 999),DisplayInfo(id: 998)] {
            let result = await service.switchInput(invalid, to: 17)
            guard case .failure(.unavailable) = result else { fatalError("Unsupported display wrote DDC") }
        }
        assert(ddc.writes.count == 3 && ddc.reads == 0)
        assert(service.switching.isEmpty)
        let g73 = DisplayInfo(id: 73, vendor: 19491, model: 10083)
        let g4q = DisplayInfo(id: 74, vendor: 19491, model: 9571)
        assert(service.options(for: g73).contains(7) && service.options(for: g73).contains(8))
        assert(!service.options(for: g73).contains(15))
        assert(service.options(for: g4q).contains(15) && service.options(for: g4q).contains(16))
        assert(service.resolve("dp1", for: g73)==7 && service.resolve("dp2", for: g73)==8)
        assert(service.resolve("dp1", for: g4q)==15)
        assert(service.resolve("15", for: g73)==15)
        assert(service.label(for: 8, display: g73)=="DisplayPort 2")
        try service.saveCustom([InputSourceDraft(name:"DP1",number:"42")],for:g73.displayUUID)
        assert(service.options(for:g73)==[42] && service.resolve("DP1",for:g73)==42)
        service.resetCustom(for: g73.displayUUID)
        assert(service.routes["test-monitor-700"] == savedRoute)
        ddc.accept = true
        ddc.writes = []
        let ju27 = DisplayInfo(id: 270, vendor: 21063, model: 10000)
        let ju24 = DisplayInfo(id: 240, vendor: 21063, model: 9237)
        // Saving cabling never writes; no inference from current input or DP defaults.
        try service.saveRoute(home: InputSourceDraft(name: "DP2", number: "15"),
                              target: InputSourceDraft(name: "DP1", number: "18"), for: ju24.displayUUID)
        try service.saveRoute(home: InputSourceDraft(name: "HDMI1", number: "0x11"),
                              target: InputSourceDraft(name: "USB-C", number: "27"), for: ju27.displayUUID)
        assert(ddc.writes.isEmpty && ddc.reads == 0)
        let routeData = UserDefaults.standard.data(forKey: "screenbridge.DisplayInputRoutes.v1")!
        let storedRoutes = try JSONDecoder().decode([String: DisplayInputRoute].self, from: routeData)
        assert(storedRoutes[ju24.displayUUID]?.home.value == 15)
        for drafts in [("DP1", "0", "DP2", "18"), ("DP1", "18", "DP2", "18"), ("DP1", "15", "dp1", "18")] {
            do {
                try service.saveRoute(home: InputSourceDraft(name: drafts.0, number: drafts.1),
                                      target: InputSourceDraft(name: drafts.2, number: drafts.3), for: ju24.displayUUID)
                fatalError("Invalid cabling saved")
            } catch { }
        }
        assert(service.routes[ju24.displayUUID]?.home.value == 15)
        await service.switchConfigured([ju24, ju27, ju24, g73, DisplayInfo(id: 1, builtin: true), DisplayInfo(id: 999)], to: .target)
        assert(ddc.writes.count == 2)
        assert(ddc.writes.contains { $0.0 == 240 && $0.1 == 18 })
        assert(ddc.writes.contains { $0.0 == 270 && $0.1 == 27 })
        assert(service.batchMessage?.contains("已跳过") == true && !service.batchSwitching)
        ddc.writes = []
        await service.switchConfigured([ju24, ju27], to: .home)
        assert(ddc.writes.count == 2)
        assert(ddc.writes.contains { $0.0 == 240 && $0.1 == 15 })
        assert(ddc.writes.contains { $0.0 == 270 && $0.1 == 17 })
        ddc.writes = []
        ddc.accept = false
        await service.switchConfigured([ju24, ju27], to: .target)
        assert(ddc.writes.count == 2 && service.batchMessage?.contains("发送失败") == true)
        ddc.accept = true
        ddc.writes = []
        service.resetRoute(for: ju24.displayUUID)
        guard case .failure(.notConfigured) = await service.switchRoute(ju24, to: .home) else {
            fatalError("Missing route must not guess DP2")
        }
        await service.switchConfigured([ju24], to: .target)
        assert(ddc.writes.isEmpty)
        _ = await service.switchRoute(ju27, to: .home)
        _ = await service.switchRoute(ju27, to: .home)
        assert(ddc.writes.count == 2 && ddc.writes.allSatisfy { $0.1 == 17 })
        ddc.writes = []
        await service.switchConfigured([], to: .home)
        assert(ddc.writes.isEmpty && ddc.reads == 0 && !service.batchSwitching)
        assert(service.resolve("dp1", for: ju24) == 18)
        assert(service.resolve("DisplayPort 2", for: ju24) == 15)
        assert(service.resolve("15", for: ju24) == 15)
        assert(service.resolve("0x12", for: ju24) == 18)
        assert(service.resolve("dp1", for: ju27) == 18)
        assert(service.resolve("dp2", for: ju27) == 16)
        assert(service.resolve("dp1", for: DisplayInfo(id: 241, vendor: 1234, model: 9237)) == 15)
        assert(service.resolve("15", for: ju27) == 15)
        assert(service.resolve("dp1", for: DisplayInfo(id: 271, vendor: 1234, model: 10000)) == 15)
        // Readback/capabilities retain standard semantics despite write remapping.
        assert(service.label(for: 15, display: ju24) == "DisplayPort 1")
        assert(service.label(for: 16, display: ju24) == "DisplayPort 2")
        try service.saveCustom([InputSourceDraft(name: "DP1", number: "42")], for: ju24.displayUUID)
        assert(service.resolve("dp1", for: ju24) == 42)
        service.resetCustom(for: ju24.displayUUID)
        assert(service.resolve("dp1", for: ju24) == 18)
        print("PASS: persisted custom lists load/save/reset and stay per-display; saving sends no command; real InputSwitchService sends immediately without readback, resends same destination, never disconnects, reports write failure, excludes internal/virtual displays")
    }
}
