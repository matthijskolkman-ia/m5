import SwiftUI
import AppKit
import CoreSpotlight

@main
struct FindMyTriggerApp: App {
    init() { registerSpotlight() }

    func registerSpotlight() {
        let attr = CSSearchableItemAttributeSet(contentType: .application)
        attr.displayName = "Ping iPhone 17 Pro"
        attr.keywords = ["iphone","17","pro","find","my","location","alert","ping","phone","sound"]
        attr.contentDescription = "Play a sound on your iPhone via Find My"
        CSSearchableIndex.default().indexSearchableItems([
            CSSearchableItem(uniqueIdentifier: "com.findmy.trigger", domainIdentifier: "findmy", attributeSet: attr)
        ]) { _ in }
    }

    var body: some Scene {
        WindowGroup {
            TriggerView().frame(width: 300, height: 200)
        }
        .windowStyle(.hiddenTitleBar).windowResizability(.contentSize).defaultSize(width: 300, height: 200)
    }
}

struct TriggerView: View {
    @State private var status = "Ready"
    @State private var pinged = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("📡 Ping iPhone").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Circle().fill(pinged ? .green : Color.white.opacity(0.1)).frame(width: 5, height: 5)
            }.padding(.horizontal, 10).padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: pinged ? "antenna.radiowaves.left.and.right" : "iphone.gen3")
                    .font(.system(size: 40))
                    .foregroundColor(pinged ? .green : .white.opacity(0.3))
                Text(status).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                Text("iPhone 17 Pro").font(.system(size: 10)).foregroundColor(.white.opacity(0.3))

                Button(action: ping) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.system(size: 10))
                        Text("Play Sound Now").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.blue).clipShape(Capsule())
                }.buttonStyle(.plain)
            }

            Spacer()
            Text("⌘Space → 'iphone 17 pro'").font(.system(size: 7)).foregroundColor(.white.opacity(0.15)).padding(.bottom, 8)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08)).preferredColorScheme(.dark)
        .onAppear { ping() }
    }

    func ping() {
        status = "Opening Find My..."
        pinged = true

        // 1. Open Find My — always works
        if let url = URL(string: "findmy://") { NSWorkspace.shared.open(url) }

        // 2. Try Shortcut if installed
        let task = Process()
        task.launchPath = "/usr/bin/shortcuts"
        task.arguments = ["run", "Ping iPhone"]

        // 3. Try to click Play Sound via accessibility
        let script = """
        tell application "Find My" to activate
        delay 0.8
        tell application "System Events"
            tell process "Find My"
                try
                    set playBtn to first button whose description contains "Play"
                    click playBtn
                end try
            end tell
        end tell
        """

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            try? task.run()
            task.waitUntilExit()

            let appleScript = NSAppleScript(source: script)
            var err: NSDictionary?
            appleScript?.executeAndReturnError(&err)

            DispatchQueue.main.async {
                status = err == nil ? "Sound played! 🔔" : "Tap 'Play Sound' in Find My"
            }
        }
    }
}
