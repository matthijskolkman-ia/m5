import SwiftUI
import AppKit

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowDelegate = WindowDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.windows.first?.delegate = self.windowDelegate
        }
        // Re-attach delegate when a new window appears (Dock click)
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            if let w = NSApp.keyWindow, w.delegate == nil {
                w.delegate = self.windowDelegate
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let w = NSApp.windows.first(where: { $0.isVisible || $0.isMiniaturized }) {
            w.makeKeyAndOrderFront(nil)
        } else if !flag {
            // Recreate window if needed
            for w in NSApp.windows where !w.isVisible { w.makeKeyAndOrderFront(nil); break }
        }
        return true
    }
}

@main
struct MixcldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MixcldView()
                .frame(minWidth: 420, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 700)
    }
}
