import Foundation

/// DisplayPort 1.2 sideband framing for a single, directly attached branch.
/// CRC polynomials and wire layout checked against Linux drm_dp_mst_topology.c
/// and joevt/AllRez. This implementation does not allocate video payloads.
enum MSTSideband {
    static func crc(_ bytes: [UInt8], bits: Int, width: Int, polynomial: Int) -> UInt8 {
        var remainder = 0
        for bit in 0..<bits {
            remainder = (remainder << 1) | Int((bytes[bit / 8] >> (7 - bit % 8)) & 1)
            if remainder & (1 << width) != 0 { remainder ^= polynomial }
        }
        for _ in 0..<width {
            remainder <<= 1
            if remainder & (1 << width) != 0 { remainder ^= polynomial }
        }
        return UInt8(remainder & ((1 << width) - 1))
    }

    static func request(_ body: [UInt8], sequence: UInt8) -> [UInt8]? {
        guard !body.isEmpty, body.count <= 44, sequence <= 1 else { return nil }
        var header: [UInt8] = [0x10, UInt8(body.count + 1), 0xc0 | (sequence << 4)]
        header[2] |= crc(header, bits: 20, width: 4, polynomial: 0x13)
        return header + body + [crc(body, bits: body.count * 8, width: 8, polynomial: 0x1d5)]
    }

    struct Fragment {
        let start: Bool
        let end: Bool
        let body: [UInt8]
    }

    static func reply(_ bytes: [UInt8], sequence: UInt8) -> Fragment? {
        guard bytes.count >= 4, bytes[0] == 0x10 else { return nil }
        let count = Int(bytes[1] & 0x3f)
        guard count > 1, count <= 45, bytes.count == 3 + count,
              (bytes[2] >> 4) & 1 == sequence,
              bytes[2] & 0xf == crc(Array(bytes.prefix(3)), bits: 20, width: 4, polynomial: 0x13)
        else { return nil }
        let body = Array(bytes[3..<(bytes.count - 1)])
        guard bytes.last == crc(body, bits: body.count * 8, width: 8, polynomial: 0x1d5) else { return nil }
        return Fragment(start: bytes[2] & 0x80 != 0, end: bytes[2] & 0x40 != 0, body: body)
    }

    static func outputPorts(_ body: [UInt8]) -> [UInt8]? {
        guard body.count >= 18, body[0] == 1 else { return nil }
        var offset = 18
        var ports: [UInt8] = []
        for _ in 0..<Int(body[17] & 15) {
            guard offset + 2 <= body.count else { return nil }
            let input = body[offset] & 0x80 != 0
            let size = input ? 2 : 20
            guard offset + size <= body.count else { return nil }
            if !input, body[offset + 1] & 0x40 != 0 {
                ports.append(body[offset] & 15)
            }
            offset += size
        }
        guard offset == body.count, Set(ports).count == ports.count else { return nil }
        return ports
    }

    static func matchesEDID(_ reply: [UInt8], port: UInt8, vendor: UInt32, product: UInt32, serial: UInt32) -> Bool {
        guard reply.count == 19, reply[0] == 0x22, reply[1] == port, reply[2] == 16 else { return false }
        let edid = Array(reply.dropFirst(3))
        guard Array(edid.prefix(8)) == [0,255,255,255,255,255,255,0] else { return false }
        let v = UInt32(edid[8]) << 8 | UInt32(edid[9])
        let p = UInt32(edid[10]) | UInt32(edid[11]) << 8
        let s = UInt32(edid[12]) | UInt32(edid[13]) << 8 | UInt32(edid[14]) << 16 | UInt32(edid[15]) << 24
        return v == vendor && p == product && s == serial
    }

    /// Strict Get VCP response decoding. Input select is an enumeration, not a scale.
    static func vcp(_ reply: [UInt8], port: UInt8, command: UInt8) -> (current: UInt16, max: UInt16)? {
        guard [UInt8(0x10), 0x60].contains(command),
              reply.count == 14, Array(reply.prefix(3)) == [0x22, port, 11] else { return nil }
        let d = Array(reply.dropFirst(3))
        guard Array(d.prefix(5)) == [0x6e,0x88,2,0,command],
              d.prefix(10).reduce(UInt8(0x50), ^) == d[10] else { return nil }
        let maximum = UInt16(d[6]) << 8 | UInt16(d[7])
        let current = UInt16(d[8]) << 8 | UInt16(d[9])
        guard command == 0x60 || (maximum > 0 && current <= maximum) else { return nil }
        return (current, maximum)
    }

    static func brightness(_ reply: [UInt8], port: UInt8) -> (current: UInt16, max: UInt16)? {
        vcp(reply, port: port, command: 0x10)
    }

    static func inputPacket(_ value: UInt16) -> [UInt8]? {
        guard value > 0 else { return nil }
        var bytes: [UInt8] = [0x51,0x84,3,0x60,UInt8(value >> 8),UInt8(value & 255)]
        bytes.append(bytes.reduce(UInt8(0x6e), ^))
        return bytes
    }
}
