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
