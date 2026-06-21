import SwiftUI
import AppKit

class AirWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
}
class AirAppDelegate: NSObject, NSApplicationDelegate {
    let wd = AirWindowDelegate()
    func applicationDidFinishLaunching(_ n: Notification) {
        DispatchQueue.main.async { NSApp.windows.first?.delegate = self.wd }
    }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows f: Bool) -> Bool {
        if !f { for w in NSApp.windows { w.makeKeyAndOrderFront(nil); break } }
        return true
    }
}

@main
struct AirScannerApp: App {
    @NSApplicationDelegateAdaptor(AirAppDelegate.self) var d
    var body: some Scene {
        WindowGroup {
            ScannerView().frame(minWidth: 380, minHeight: 440)
        }
        .windowStyle(.hiddenTitleBar).windowResizability(.contentSize)
        .defaultSize(width: 380, height: 480)
    }
}
