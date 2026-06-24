import SwiftUI
import AppKit

class DashWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
}

class DashAppDelegate: NSObject, NSApplicationDelegate {
    let wd = DashWindowDelegate()
    func applicationDidFinishLaunching(_ n: Notification) {
        DispatchQueue.main.async { NSApp.windows.first?.delegate = self.wd }
    }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows f: Bool) -> Bool {
        if !f { for w in NSApp.windows { w.makeKeyAndOrderFront(nil); break } }
        return true
    }
}

@main
struct DashboardApp: App {
    @NSApplicationDelegateAdaptor(DashAppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 520)
                .preferredColorScheme(.dark)
                .background(Color(red: 0.06, green: 0.06, blue: 0.10))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 560)
    }
}
