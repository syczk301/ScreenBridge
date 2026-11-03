import Foundation

@main
struct InputConfigurationChecks {
    @MainActor static func main() async throws {
        let valid: [(String, UInt16)] = [("17",17),("0x11",17),("0XFFFF",65535),(" 209 ",209),("1",1)]
        for (text, value) in valid { assert(InputSourceConfiguration.parseNumber(text) == value) }
        for text in ["", "0", "0x0", "65536", "-1", "+17", "0x", "0x10000", "17.5", "HDMI 1"] {
            assert(InputSourceConfiguration.parseNumber(text) == nil, text)
        }
        let inputs = try InputSourceConfiguration.validate([
            InputSourceDraft(name: " Work Mac ", number: "0x0F"),
            InputSourceDraft(name: "Game PC", number: "17")
        ])
        assert(inputs[0].name == "Work Mac" && inputs[0].value == 15)
        for drafts in [
            [], [InputSourceDraft(name: "", number: "17")],
            [InputSourceDraft(name: "A", number: "17"),InputSourceDraft(name: "B", number: "0x11")],
            [InputSourceDraft(name: String(repeating: "A", count: 65), number: "17")],
            [InputSourceDraft(name: "A", number: "0")]
        ] {
            do { _ = try InputSourceConfiguration.validate(drafts); fatalError("Accepted invalid configuration") }
            catch is InputSourceConfiguration.ValidationError { }
        }
        let store = ["monitor-A": inputs, "monitor-B": [CustomInputSource(name: "USB-C", value: 27)]]
        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode([String: [CustomInputSource]].self, from: data)
        assert(decoded == store)
        var writes: [UInt16] = []
        let first = await DirectInputCommand.send(17) { value in writes.append(value); return true }
        let again = await DirectInputCommand.send(17) { value in writes.append(value); return true }
        let failed = await DirectInputCommand.send(15) { value in writes.append(value); return false }
        let invalid = await DirectInputCommand.send(0) { value in writes.append(value); return true }
        assert(first && again && !failed && !invalid)
        assert(writes == [17,17,15])
        print("PASS: decimal/hex bounds, invalid/duplicate names and values, per-display JSON round-trip, immediate and repeated writes, failed writes")
    }
}
