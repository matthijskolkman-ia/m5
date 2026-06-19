import SwiftUI

struct TrackRowView: View {
    let track: Track
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            // Track number
            Text(String(format: "%02d", index + 1))
                .font(.title3).bold()
                .foregroundColor(.purple)
                .frame(width: 32, alignment: .trailing)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body).fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Tags
                HStack(spacing: 6) {
                    Tag(text: track.genre)
                    Tag(text: "\(track.year)")
                    Tag(text: "\(track.bpm) BPM")
                    Tag(text: track.key)
                }
            }

            Spacer()

            // Duration
            Text(track.duration)
                .font(.subheadline).monospacedDigit()
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct Tag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.05))
            .cornerRadius(4)
    }
}
