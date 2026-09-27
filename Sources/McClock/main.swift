import AppKit

@MainActor
final class ClockAppDelegate: NSObject, NSApplicationDelegate {
    private let secondsKey = "showSeconds"
    private var statusItem: NSStatusItem!
    private var secondsItem: NSMenuItem!
    private var timer: Timer?

    private var showSeconds: Bool {
        UserDefaults.standard.bool(forKey: secondsKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "McClock"

        let menu = NSMenu()
        secondsItem = NSMenuItem(title: "Show Seconds", action: #selector(toggleSeconds), keyEquivalent: "")
        secondsItem.target = self
        menu.addItem(secondsItem)

        let copyItem = NSMenuItem(title: "Copy Date & Time", action: #selector(copyTime), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit McClock", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        refresh()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self,
                                     selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    @objc private func refresh() {
        let now = Date()
        statusItem.button?.title = ClockFormatter.display(at: now, includeSeconds: showSeconds)
        secondsItem.state = showSeconds ? .on : .off
    }

    @objc private func toggleSeconds() {
        UserDefaults.standard.set(!showSeconds, forKey: secondsKey)
        refresh()
    }

    @objc private func copyTime() {
        guard let value = statusItem.button?.title else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = ClockAppDelegate()
    application.delegate = delegate
    application.run()
}
