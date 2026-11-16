// Run with DDCInputSource.swift concatenated before this file.
import Foundation

// A physical external display stays discoverable even when DDC reads/brightness fail.
assert(DDCInputSource.canOfferSwitching(isBuiltin: false, isVirtual: false))
assert(!DDCInputSource.canOfferSwitching(isBuiltin: true, isVirtual: false))
assert(!DDCInputSource.canOfferSwitching(isBuiltin: false, isVirtual: true))
assert(!DDCInputSource.canOfferSwitching(isBuiltin: true, isVirtual: true))
// Preserve standard fallbacks and advertised input parsing.
assert(DDCInputSource.standard == [0x0F, 0x10, 0x11, 0x12, 0x1B])
assert(DDCInputSource.value(from: "HDMI 1") == 0x11)
assert(DDCInputSource.value(from: "dp2") == 0x10)
assert(DDCInputSource.value(from: "usb-c") == 0x1B)
assert(DDCInputSource.value(from: "invalid") == nil)
assert(DDCInputSource.values(inCapabilities: "(vcp(10 60(0F 11 12)))") == [0x0F, 0x11, 0x12])
print("check-input-source: all assertions passed")

assert(DDCInputSource.singleInputWrite(command: 0x60, vendor: 21063, model: 10000))
assert(!DDCInputSource.singleInputWrite(command: 0x10, vendor: 21063, model: 10000))
assert(!DDCInputSource.singleInputWrite(command: 0x60, vendor: 21063, model: 9237))
assert(!DDCInputSource.singleInputWrite(command: 0x60, vendor: 1234, model: 10000))
