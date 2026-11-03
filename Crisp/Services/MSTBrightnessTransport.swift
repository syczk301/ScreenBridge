import Foundation
import CoreGraphics
import IOKit
import os.log

#if arch(arm64)
@_silgen_name("IODPDeviceCreateWithService")
private func mstCreateDevice(_ allocator: CFAllocator?, _ service: io_service_t) -> UnsafeMutableRawPointer?
@_silgen_name("IODPDeviceReadDPCD")
private func mstReadDPCD(_ device: UnsafeMutableRawPointer, _ address: UInt32, _ bytes: UnsafeMutableRawPointer, _ count: UInt32) -> IOReturn
@_silgen_name("IODPDeviceWriteDPCD")
private func mstWriteDPCD(_ device: UnsafeMutableRawPointer, _ address: UInt32, _ bytes: UnsafeMutableRawPointer, _ count: UInt32) -> IOReturn

/// Narrow compatibility transport verified on HP G2 SYNAS3 -> G4Q.
/// All operations are serialized, identity checked and limited to VCP brightness and input select.
/// Never writes MST_EN, PHY, payload-allocation, power or firmware registers.
final class MSTBrightnessTransport: @unchecked Sendable {
    static let shared = MSTBrightnessTransport()
    private let lock = NSLock()
    private let log = Logger(subsystem: "local.screenbridge.app", category: "mst-brightness")
    private var ports: [UInt64: UInt8] = [:]

    private struct Channel {
        let device: UnsafeMutableRawPointer
        let entryID: UInt64
        let displayID: CGDirectDisplayID
    }

    private func read(_ device: UnsafeMutableRawPointer, _ address: UInt32, _ count: Int) -> [UInt8]? {
        guard count > 0, count <= 16 else { return nil }
        var bytes = [UInt8](repeating: 0, count: count)
        guard mstReadDPCD(device, address, &bytes, UInt32(count)) == kIOReturnSuccess else { return nil }
        return bytes
    }

    private func write(_ device: UnsafeMutableRawPointer, _ address: UInt32, _ bytes: [UInt8]) -> Bool {
        // Only the request mailbox and the reply-ready W1C acknowledgement are writable.
        guard (!bytes.isEmpty && bytes.count <= 16 && address >= 0x1000 && address + UInt32(bytes.count) <= 0x1030)
                || (address == 0x201 && bytes == [0x10]) else { return false }
        var buffer = bytes
        return mstWriteDPCD(device, address, &buffer, UInt32(buffer.count)) == kIOReturnSuccess
    }

    private func exchange(_ channel: Channel, _ body: [UInt8]) -> [UInt8]? {
        guard let old = read(channel.device, 0x1400, 3) else { return nil }
        // Derive sequence from the last mailbox frame, including other diagnostic clients.
        let sequence = ((old[2] >> 4) & 1) ^ 1
        guard let request = MSTSideband.request(body, sequence: sequence) else { return nil }
        for offset in stride(from: 0, to: request.count, by: 16) {
            guard write(channel.device, 0x1000 + UInt32(offset), Array(request[offset..<min(offset + 16, request.count)])) else { return nil }
        }
        var previous: [UInt8] = []
        var assembled: [UInt8] = []
        var started = false
        let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
        while DispatchTime.now().uptimeNanoseconds < deadline {
            Thread.sleep(forTimeInterval: 0.01)
            // The DCP consumes the IRQ bit on this host. Poll the validated mailbox itself.
            guard let first = read(channel.device, 0x1400, 16) else { return nil }
            guard first[0] == 0x10, (first[2] >> 4) & 1 == sequence else { continue }
            let length = 3 + Int(first[1] & 63)
            guard length >= 5, length <= 48 else { continue }
            var frame = Array(first.prefix(length))
            if length > 16 {
                for offset in stride(from: 16, to: length, by: 16) {
                    guard let part = read(channel.device, 0x1400 + UInt32(offset), min(16, length - offset)) else { return nil }
                    frame += part
                }
            }
            guard frame != previous, let fragment = MSTSideband.reply(frame, sequence: sequence) else { continue }
            if fragment.start {
                guard let opcode = fragment.body.first, opcode & 127 == body[0] else { continue }
                assembled = []
                started = true
            }
            guard started, assembled.count + fragment.body.count <= 256 else { return nil }
            assembled += fragment.body
            previous = frame
            guard write(channel.device, 0x201, [0x10]) else { return nil }
            if fragment.end { return assembled.first == body.first ? assembled : nil }
        }
        log.notice("MST reply timeout; no display configuration changed")
        return nil
    }

    private func channel(for id: CGDirectDisplayID, location: String?) -> Channel? {
        guard CGDisplayIsOnline(id) != 0, CGDisplayVendorNumber(id) == 19491,
              CGDisplayModelNumber(id) == 9571, let location else { return nil }
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(root, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var matchingFramebuffer = false
        var candidates: [(io_service_t, UInt64)] = []
        defer { candidates.forEach { IOObjectRelease($0.0) } }
        while case let entry = IOIteratorNext(iterator), entry != IO_OBJECT_NULL {
            defer { IOObjectRelease(entry) }
            if IOObjectConformsTo(entry, "IOMobileFramebuffer") != 0 {
                var path = [CChar](repeating: 0, count: 4096)
                matchingFramebuffer = IORegistryEntryGetPath(entry, kIOServicePlane, &path) == KERN_SUCCESS && String(cString: path) == location
            }
            var name = [CChar](repeating: 0, count: 128)
            guard matchingFramebuffer, IOObjectGetClass(entry, &name) == KERN_SUCCESS,
                  String(cString: name) == "DCPDPDeviceProxy" else { continue }
            var key: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(entry, &key) == KERN_SUCCESS else { continue }
            IOObjectRetain(entry)
            candidates.append((entry, key))
        }
        guard candidates.count == 1, let device = mstCreateDevice(kCFAllocatorDefault, candidates[0].0) else { return nil }
        guard let cap = read(device, 0x21, 1), cap[0] & 1 != 0,
              let branch = read(device, 0x500, 16), Array(branch.prefix(9)) == [0x90,0xcc,0x24,0x53,0x59,0x4e,0x41,0x53,0x33] else {
            Unmanaged<AnyObject>.fromOpaque(device).release()
            return nil
        }
        return Channel(device: device, entryID: candidates[0].1, displayID: id)
    }

    private func identifies(_ channel: Channel, _ port: UInt8) -> Bool {
        guard port > 0, port <= 15,
              let edid = exchange(channel, [0x22, port << 4 | 1, 0x50, 1, 0, 0x10, 0x50, 16]) else { return false }
        return MSTSideband.matchesEDID(edid, port: port, vendor: CGDisplayVendorNumber(channel.displayID),
                                      product: CGDisplayModelNumber(channel.displayID), serial: CGDisplaySerialNumber(channel.displayID))
    }

    private func port(for channel: Channel) -> UInt8? {
        if let cached = ports[channel.entryID], identifies(channel, cached) { return cached }
        ports.removeValue(forKey: channel.entryID)
        guard let topology = exchange(channel, [1]), let active = MSTSideband.outputPorts(topology) else { return nil }
        let matching = active.filter { identifies(channel, $0) }
        guard matching.count == 1 else { return nil }
        ports[channel.entryID] = matching[0]
        log.notice("G4Q matched to verified SYNAS3 MST port \(matching[0], privacy: .public)")
        return matching[0]
    }

    private func sendDDC(_ channel: Channel, port: UInt8, bytes: [UInt8]) -> Bool {
        guard let reply = exchange(channel, [0x23, port << 4, 0x37, UInt8(bytes.count)] + bytes) else { return false }
        return reply == [0x23, port]
    }

    private func brightness(_ channel: Channel, port: UInt8) -> (current: UInt16, max: UInt16)? {
        guard sendDDC(channel, port: port, bytes: [0x51,0x82,1,0x10,0xac]) else { return nil }
        Thread.sleep(forTimeInterval: 0.05)
        guard let reply = exchange(channel, [0x22, port << 4, 0x37, 11]) else { return nil }
        return MSTSideband.brightness(reply, port: port)
    }

    func readBrightness(displayID: CGDirectDisplayID, location: String?) -> (current: UInt16, max: UInt16)? {
        lock.lock(); defer { lock.unlock() }
        guard let channel = channel(for: displayID, location: location) else { return nil }
        defer { Unmanaged<AnyObject>.fromOpaque(channel.device).release() }
        guard let port = port(for: channel), let value = brightness(channel, port: port) else { return nil }
        log.notice("MST hardware brightness display \(displayID, privacy: .public): \(value.current, privacy: .public)/\(value.max, privacy: .public)")
        return value
    }

    func readCapabilitiesChunk(displayID: CGDirectDisplayID, location: String?, offset: Int) -> [UInt8]? {
        guard offset >= 0, offset < 4096 else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard let channel = channel(for: displayID, location: location) else { return nil }
        defer { Unmanaged<AnyObject>.fromOpaque(channel.device).release() }
        guard let port = port(for: channel) else { return nil }
        let packet = [UInt8(0x51)] + DDCCapabilities.request(offset: offset)
        for _ in 0..<2 {
            guard sendDDC(channel, port: port, bytes: packet) else { return nil }
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.05)
        guard let reply = exchange(channel, [0x22, port << 4, 0x37, 38]),
              reply.count == 41, Array(reply.prefix(3)) == [0x22, port, 38] else { return nil }
        return DDCCapabilities.data(fromReply: Array(reply.dropFirst(3)), offset: offset)
    }

    func readInput(displayID: CGDirectDisplayID, location: String?) -> (current: UInt16, max: UInt16)? {
        lock.lock(); defer { lock.unlock() }
        guard let channel = channel(for: displayID, location: location) else { return nil }
        defer { Unmanaged<AnyObject>.fromOpaque(channel.device).release() }
        guard let port = port(for: channel) else { return nil }
        for _ in 0..<2 {
            guard sendDDC(channel, port: port, bytes: [0x51,0x82,1,0x60,0xdc]) else { return nil }
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.05)
        guard let reply = exchange(channel, [0x22, port << 4, 0x37, 11]) else { return nil }
        return MSTSideband.vcp(reply, port: port, command: 0x60)
    }

    /// Acknowledgement means transport delivery only. Switching may remove the link,
    /// so do not require a current-input read or a post-switch readback.
    func writeInput(displayID: CGDirectDisplayID, location: String?, value: UInt16) -> Bool {
        guard let packet = MSTSideband.inputPacket(value) else { return false }
        lock.lock(); defer { lock.unlock() }
        guard let channel = channel(for: displayID, location: location) else { return false }
        defer { Unmanaged<AnyObject>.fromOpaque(channel.device).release() }
        guard let port = port(for: channel) else { return false }
        let sent = sendDDC(channel, port: port, bytes: packet)
        log.notice("MST input command display \(displayID, privacy: .public) value \(value, privacy: .public) acknowledged: \(sent, privacy: .public)")
        return sent
    }

    func writeBrightness(displayID: CGDirectDisplayID, location: String?, value: UInt16) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let channel = channel(for: displayID, location: location) else { return false }
        defer { Unmanaged<AnyObject>.fromOpaque(channel.device).release() }
        guard let port = port(for: channel), let before = brightness(channel, port: port), value <= before.max else { return false }
        var packet: [UInt8] = [0x51,0x84,3,0x10,UInt8(value >> 8),UInt8(value & 255)]
        packet.append(packet.reduce(UInt8(0x6e), ^))
        guard sendDDC(channel, port: port, bytes: packet) else { return false }
        Thread.sleep(forTimeInterval: 0.05)
        guard let after = brightness(channel, port: port), after.current == value, after.max == before.max else { return false }
        log.notice("MST hardware write verified display \(displayID, privacy: .public): \(value, privacy: .public)")
        return true
    }
}
#endif
