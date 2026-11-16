import Foundation

struct CustomInputSource: Codable, Equatable, Identifiable {
    var id: UInt16 { value }
    let name: String
    let value: UInt16
}

struct InputSourceDraft: Identifiable {
    let id = UUID()
    var name: String
    var number: String
}

enum InputSourceConfiguration {
    enum ValidationError: Error, LocalizedError {
        case empty, name, value, duplicate
        var errorDescription: String? {
            switch self {
            case .empty: String(localized: "Add at least one input source.")
            case .name: String(localized: "Each input needs a name of 1–64 characters.")
            case .value: String(localized: "Use a decimal or 0x hexadecimal value from 1 to 65535.")
            case .duplicate: String(localized: "Input values must be unique for this display.")
            }
        }
    }

    static func parseNumber(_ text: String) -> UInt16? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isHex = text.lowercased().hasPrefix("0x")
        let digits = isHex ? String(text.dropFirst(2)) : text
        guard !digits.isEmpty,
              digits.allSatisfy({ isHex ? $0.isHexDigit : ("0"..."9").contains(String($0)) }),
              let value = UInt16(digits, radix: isHex ? 16 : 10), value > 0 else { return nil }
        return value
    }

    static func validate(_ drafts: [InputSourceDraft]) throws -> [CustomInputSource] {
        guard !drafts.isEmpty else { throw ValidationError.empty }
        var used = Set<UInt16>()
        return try drafts.map { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 64 else { throw ValidationError.name }
            guard let value = parseNumber(draft.number) else { throw ValidationError.value }
            guard used.insert(value).inserted else { throw ValidationError.duplicate }
            return CustomInputSource(name: name, value: value)
        }
    }
}

/// A direct command has no dependency on current-input readback or return-port state.
@MainActor
enum DirectInputCommand {
    static func send(_ value: UInt16, writer: (UInt16) async -> Bool) async -> Bool {
        guard value > 0 else { return false }
        return await writer(value)
    }
}

/// Explicit cabling roles. Values are final Set VCP commands, never Get VCP values.
struct DisplayInputRoute: Codable, Equatable {
    let home: CustomInputSource
    let target: CustomInputSource

    var isValid: Bool {
        home.value > 0 && target.value > 0 && home.value != target.value
            && !home.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !target.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && home.name.count <= 64 && target.name.count <= 64
            && home.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(target.name.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
    }
    static func validated(home: InputSourceDraft, target: InputSourceDraft) throws -> Self {
        let inputs = try InputSourceConfiguration.validate([home, target])
        let route = Self(home: inputs[0], target: inputs[1])
        guard route.isValid else { throw InputSourceConfiguration.ValidationError.duplicate }
        return route
    }
}

/// Only measured read-to-write pairs can be used for automatic home-port suggestions.
enum VerifiedInputReadback {
    static func input(_ read: UInt16, vendor: UInt32, model: UInt32) -> CustomInputSource? {
        switch (vendor, model, read) {
        case (21063, 9237, 15), (21063, 10000, 15):
            return CustomInputSource(name: "DP1", value: 18)
        case (21063, 9237, 16): return CustomInputSource(name: "DP2", value: 15)
        case (19491, 10083, 7): return CustomInputSource(name: "DP1", value: 7)
        case (19491, 10083, 8): return CustomInputSource(name: "DP2", value: 8)
        case (19491, 9571, 15): return CustomInputSource(name: "DP1", value: 15)
        case (19491, 9571, 16): return CustomInputSource(name: "DP2", value: 16)
        default: return nil
        }
    }
}
