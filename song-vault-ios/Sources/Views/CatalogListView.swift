import SwiftUI

struct CatalogListView: View {
    let catalog: Catalog
    let remaining: Int
    let total: Int

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Catalog Unlocked")
                        .font(.title2).bold()
                        .foregroundColor(.white)

                    Text("\(catalog.tracks.count) tracks · \(catalog.owner)")
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "ticket.fill").font(.caption2)
                        Text("\(remaining) of \(total) authorizations remaining")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.clear)
            }

            // Tracks
            Section {
                ForEach(Array(catalog.tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(track: track, index: index)
                        .listRowBackground(Color.white.opacity(0.03))
                        .listRowSeparatorTint(Color.white.opacity(0.06))
                }
            } header: {
                Text("TRACKS")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
