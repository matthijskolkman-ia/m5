import SwiftUI
import AppKit

class CoinWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
}

class CoinAppDelegate: NSObject, NSApplicationDelegate {
    let wd = CoinWindowDelegate()
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { NSApp.windows.first?.delegate = self.wd }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { for w in NSApp.windows { w.makeKeyAndOrderFront(nil); break } }
        return true
    }
}

@main
struct CoinWatchApp: App {
    @NSApplicationDelegateAdaptor(CoinAppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            PriceView()
                .frame(minWidth: 340, minHeight: 440)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 340, height: 480)
    }
}
