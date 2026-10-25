import AppKit
import ServiceManagement

final class ModeChoice: NSObject {
    let display: Display
    let mode: DisplayMode

    init(display: Display, mode: DisplayMode) {
        self.display = display
        self.mode = mode
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "HiDPI")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if !UserDefaults.standard.bool(forKey: "didRegisterLoginItem") {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "didRegisterLoginItem")
        }

        CGDisplayRegisterReconfigurationCallback({ display, flags, _ in
            guard flags.contains(.addFlag) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { PreferredMode.restore(on: display) }
        }, nil)
        for display in Display.external() {
            PreferredMode.restore(on: display.id)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let displays = Display.external()
        if displays.isEmpty {
            menu.addItem(disabledItem("No external display"))
        }
        for display in displays {
            addSection(for: display, to: menu)
            menu.addItem(.separator())
        }

        let settings = NSMenuItem(title: "Displays Settings…", action: #selector(openDisplaySettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.target = self
        menu.addItem(login)

        menu.addItem(NSMenuItem(title: "Quit HiDPI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func addSection(for display: Display, to menu: NSMenu) {
        menu.addItem(sectionHeader(display.name))
        if let current = display.current {
            menu.addItem(disabledItem("\(current.width) × \(current.height)\(current.hiDPI ? " HiDPI" : "") · \(current.refreshRate) Hz"))
        }

        let hiDPI = display.sizes(hiDPI: true)
        if !hiDPI.isEmpty {
            menu.addItem(disabledItem("HiDPI"))
            for size in hiDPI {
                menu.addItem(sizeItem(size, on: display))
            }
        }

        let lowResolution = display.sizes(hiDPI: false)
        if !lowResolution.isEmpty {
            let submenu = NSMenu()
            for size in lowResolution {
                submenu.addItem(sizeItem(size, on: display))
            }
            let item = NSMenuItem(title: "Low Resolution", action: nil, keyEquivalent: "")
            item.submenu = submenu
            item.state = display.current?.hiDPI == false ? .mixed : .off
            menu.addItem(item)
        }

        if let current = display.current {
            let submenu = NSMenu()
            for mode in display.refreshRates(for: current) {
                let item = NSMenuItem(title: "\(mode.refreshRate) Hz", action: #selector(selectMode(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = ModeChoice(display: display, mode: mode)
                item.state = mode.refreshRate == current.refreshRate ? .on : .off
                submenu.addItem(item)
            }
            let item = NSMenuItem(title: "Refresh Rate", action: nil, keyEquivalent: "")
            item.submenu = submenu
            menu.addItem(item)
        }
    }

    private func sizeItem(_ size: DisplayMode, on display: Display) -> NSMenuItem {
        let isNative = !size.hiDPI && size.sameSize(as: display.native ?? size)
        let item = NSMenuItem(title: "\(size.width) × \(size.height)\(isNative ? " (native)" : "")",
                              action: #selector(selectSize(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = ModeChoice(display: display, mode: size)
        item.state = display.current?.sameSize(as: size) == true ? .on : .off
        return item
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14, *) {
            return .sectionHeader(title: title)
        }
        return disabledItem(title)
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? ModeChoice,
              let mode = choice.display.mode(like: choice.mode, refreshRate: choice.display.current?.refreshRate) else { return }
        apply(mode, on: choice.display)
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? ModeChoice else { return }
        apply(choice.mode, on: choice.display)
    }

    private func apply(_ mode: DisplayMode, on display: Display) {
        if display.apply(mode) {
            PreferredMode.save(mode, for: display.id)
        }
    }

    @objc private func openDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try? service.unregister()
        } else {
            try? service.register()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
