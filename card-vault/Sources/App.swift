import SwiftUI

// MARK: - App Entry

@main
struct CardVaultApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var connectivity = ConnectivityManager()
    @StateObject private var proximity = ProximityBeacon()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(connectivity)
                .environmentObject(proximity)
                .frame(minWidth: 1000, minHeight: 600)
                .preferredColorScheme(.dark)
                .onAppear {
                    // If no box selected, select the first
                    if store.selectedBoxID == nil, let first = store.boxes.first {
                        store.selectedBoxID = first.id
                    }
                    proximity.startAdvertising()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Vault") {
                Button("New Box") {
                    store.addBox(Box.new(name: "Booster Box", set: "New Set", type: .boosterBox))
                }.keyboardShortcut("b", modifiers: [.command, .shift])

                if let boxID = store.selectedBoxID {
                    Button("Add Pack") {
                        let count = store.selectedBox?.packs.count ?? 0
                        let serial = CardStore.generateSerial(boxName: store.selectedBox?.name ?? "BOX", packPosition: count + 1)
                        store.addPack(to: boxID, pack: Pack.new(serial: serial, position: count + 1))
                    }.keyboardShortcut("n", modifiers: .command)
                }
            }
        }
    }
}
