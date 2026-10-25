import AppKit
import CoreGraphics

struct DisplayMode {
    let number: Int32
    let width: Int
    let height: Int
    let hiDPI: Bool
    let refreshRate: Int

    func sameSize(as other: DisplayMode) -> Bool {
        width == other.width && height == other.height && hiDPI == other.hiDPI
    }

    func matches(_ other: DisplayMode) -> Bool {
        sameSize(as: other) && refreshRate == other.refreshRate
    }
}

/// Modes come from the private CoreGraphics list, which includes HiDPI modes macOS hides.
struct Display {
    let id: CGDirectDisplayID
    let name: String
    let modes: [DisplayMode]
    let current: DisplayMode?

    static func external() -> [Display] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count)
        return ids.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }.map(Display.init(id:))
    }

    init(id: CGDirectDisplayID) {
        self.id = id
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }
        name = screen?.localizedName ?? "Display \(id)"

        var count: Int32 = 0
        var currentNumber: Int32 = -1
        CGSGetNumberOfDisplayModes(id, &count)
        CGSGetCurrentDisplayMode(id, &currentNumber)
        var all: [DisplayMode] = []
        for index in 0..<count {
            var description = CGSDisplayModeDescription()
            CGSGetDisplayModeDescriptionOfLength(id, index, &description, Int32(MemoryLayout<CGSDisplayModeDescription>.size))
            all.append(DisplayMode(
                number: Int32(description.mode), width: Int(description.width), height: Int(description.height),
                hiDPI: description.density > 1.5, refreshRate: Int(description.freq)))
        }
        current = all.first { $0.number == currentNumber }

        var unique: [DisplayMode] = []
        for mode in all where !unique.contains(where: { $0.matches(mode) }) {
            unique.append(mode)
        }
        modes = unique
    }

    /// Not simply the largest mode: many monitors also accept signals above their panel resolution.
    var native: DisplayMode? {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        let publicModes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] ?? []
        if let flagged = publicModes.first(where: { $0.ioFlags & UInt32(kDisplayModeNativeFlag) != 0 }),
           let mode = modes.first(where: { !$0.hiDPI && $0.width == flagged.pixelWidth && $0.height == flagged.pixelHeight }) {
            return mode
        }
        return modes.filter { !$0.hiDPI }.max { $0.width * $0.height < $1.width * $1.height }
    }

    func sizes(hiDPI: Bool) -> [DisplayMode] {
        guard let native else { return [] }
        let aspect = Double(native.width) / Double(native.height)
        var result: [DisplayMode] = []
        for mode in modes
        where mode.hiDPI == hiDPI && mode.width >= 1280
            && abs(Double(mode.width) / Double(mode.height) - aspect) < 0.02
            && !result.contains(where: { $0.sameSize(as: mode) }) {
            result.append(mode)
        }
        return result.sorted { $0.width > $1.width }
    }

    func refreshRates(for size: DisplayMode) -> [DisplayMode] {
        modes.filter { $0.sameSize(as: size) }.sorted { $0.refreshRate > $1.refreshRate }
    }

    func mode(like size: DisplayMode, refreshRate: Int?) -> DisplayMode? {
        let candidates = refreshRates(for: size)
        return candidates.first { $0.refreshRate == refreshRate } ?? candidates.first
    }

    @discardableResult
    func apply(_ mode: DisplayMode) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        CGSConfigureDisplayMode(config, id, mode.number)
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
}

/// Restores the chosen mode per monitor model on connect, since macOS can fall back from hidden modes.
enum PreferredMode {
    private static func key(_ id: CGDirectDisplayID) -> String {
        "preferredMode.\(CGDisplayVendorNumber(id)).\(CGDisplayModelNumber(id))"
    }

    static func save(_ mode: DisplayMode, for id: CGDirectDisplayID) {
        UserDefaults.standard.set([mode.width, mode.height, mode.hiDPI ? 1 : 0, mode.refreshRate], forKey: key(id))
    }

    static func restore(on id: CGDirectDisplayID) {
        guard CGDisplayIsBuiltin(id) == 0 else { return }
        let display = Display(id: id)
        guard let saved = UserDefaults.standard.array(forKey: key(id)) as? [Int], saved.count == 4 else {
            if let current = display.current { save(current, for: id) }
            return
        }
        let wanted = DisplayMode(number: -1, width: saved[0], height: saved[1], hiDPI: saved[2] == 1, refreshRate: saved[3])
        guard display.current?.matches(wanted) != true,
              let mode = display.mode(like: wanted, refreshRate: wanted.refreshRate) else { return }
        display.apply(mode)
    }
}
