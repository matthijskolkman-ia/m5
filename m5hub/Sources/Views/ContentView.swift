import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NotesView()
                .tabItem {
                    Image(systemName: "note.text")
                    Text("Notes")
                }

            AgentsView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Agents")
                }

            GitView()
                .tabItem {
                    Image(systemName: "arrow.triangle.branch")
                    Text("Git")
                }

            AirScanView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("AirScan")
                }
        }
        .preferredColorScheme(.dark)
    }
}
