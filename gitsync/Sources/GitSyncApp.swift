import SwiftUI
import AppKit

class SyncWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

class SyncAppDelegate: NSObject, NSApplicationDelegate {
    let windowDelegate = SyncWindowDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.windows.first?.delegate = self.windowDelegate
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for w in NSApp.windows { w.makeKeyAndOrderFront(nil); break }
        }
        return true
    }
}

@main
struct GitSyncApp: App {
    @NSApplicationDelegateAdaptor(SyncAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SyncView()
                .frame(minWidth: 320, minHeight: 380)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 380)
    }
}
