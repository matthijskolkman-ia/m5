import SwiftUI
import WebKit
import AVKit
import AppKit

// MARK: - Track Model

struct BandcampTrack: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let streamURL: String
    let artURL: String
    let duration: String
}

// MARK: - Main Player View

struct PlayerView: View {
    @State private var username = ""
    @State private var tracks: [BandcampTrack] = []
    @State private var currentTrack: BandcampTrack?
    @State private var isPlaying = false
    @State private var showBrowser = true
    @State private var browserURL = URL(string: "https://bandcamp.com")!
    @AppStorage("bcUser") private var savedUser = ""
    @State private var scraperMsg = ""
    @StateObject private var player = AudioPlayer()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 14)).foregroundColor(.teal)
                Text("Bndply")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()

                // Username + load
                TextField("username", text: $username)
                    .textFieldStyle(.plain).font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 100)
                    .onSubmit { loadCollection() }

                Button("Load") { loadCollection() }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.teal.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 3))
                    .buttonStyle(.plain)

                Button("Login") { browserURL = URL(string: "https://bandcamp.com/login")!; showBrowser = true }
                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
                    .buttonStyle(.plain)

                Button(action: { showBrowser.toggle() }) {
                    Image(systemName: showBrowser ? "globe" : "music.note.list")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(red: 0.06, green: 0.06, blue: 0.10))
            Divider().background(Color.white.opacity(0.06))

            if showBrowser {
                // Browser
                TrackScraperWebView(
                    url: browserURL,
                    onTracksFound: { t in 
                        tracks = t
                        scraperMsg = t.isEmpty ? "No tracks — try Login first" : "\(t.count) tracks"
                    },
                    onURLClick: { browserURL = $0 }
                )
            } else if !tracks.isEmpty {
                // Track list header
                HStack {
                    Text(scraperMsg)
                        .font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.25))
                    Spacer()
                }.padding(.horizontal, 10).padding(.top, 4)
                // Track list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(tracks) { track in
                            TrackRow(
                                track: track,
                                isPlaying: currentTrack == track && player.isPlaying,
                                onPlay: { playTrack(track) }
                            )
                            Divider().padding(.leading, 44).background(Color.white.opacity(0.04))
                        }
                    }
                }

                // Now playing bar
                if let track = currentTrack {
                    NowPlayingBar(track: track, player: player, isPlaying: $isPlaying)
                }
            } else if showBrowser && tracks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "music.note").font(.system(size: 32)).foregroundColor(.white.opacity(0.1))
                    Text(scraperMsg.isEmpty ? "Login first, then Load" : scraperMsg)
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.25)).multilineTextAlignment(.center)
                    Text("1. Click Login → sign in\n2. Enter username → click Load")
                        .font(.system(size: 9)).foregroundColor(.white.opacity(0.15)).multilineTextAlignment(.center)
                }
                Spacer()
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
        .onAppear {
            if !savedUser.isEmpty { username = savedUser }
        }
    }

    func loadCollection() {
        let u = username.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty else { return }
        savedUser = u
        // Load API directly — cookies from login session will be sent
        browserURL = URL(string: "https://bandcamp.com/api/fan/2/collection_items")!
        scraperMsg = "Loading…"
        showBrowser = false  // hide browser, show status
    }

    func playTrack(_ track: BandcampTrack) {
        currentTrack = track
        player.play(url: track.streamURL)
        isPlaying = true
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let track: BandcampTrack
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: track.artURL)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.white.opacity(0.05)
                }
                .frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title).font(.system(size: 10, weight: .medium))
                        .foregroundColor(isPlaying ? .teal : .white.opacity(0.7)).lineLimit(1)
                    Text(track.artist).font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3)).lineLimit(1)
                }
                Spacer()
                Text(track.duration).font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                    .font(.system(size: 10)).foregroundColor(isPlaying ? .teal : .white.opacity(0.3))
            }.padding(.horizontal, 10).padding(.vertical, 6)
        }.buttonStyle(.plain)
    }
}

// MARK: - Now Playing Bar

struct NowPlayingBar: View {
    let track: BandcampTrack
    @ObservedObject var player: AudioPlayer
    @Binding var isPlaying: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: track.artURL)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { Color.white.opacity(0.05) }
                .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title).font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8)).lineLimit(1)
                    Text(track.artist).font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35)).lineLimit(1)
                }
                Spacer()

                // AirPlay picker
                AirPlayButton()
                    .frame(width: 24, height: 24)

                Button(action: {
                    if player.isPlaying { player.pause(); isPlaying = false }
                    else { player.resume(); isPlaying = true }
                }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16)).foregroundColor(.white)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(red: 0.06, green: 0.06, blue: 0.12))
        }
    }
}

// MARK: - AirPlay Button

struct AirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.isRoutePickerButtonBordered = false
        return v
    }
    func updateNSView(_ v: AVRoutePickerView, context: Context) {}
}

// MARK: - Audio Player

final class AudioPlayer: ObservableObject {
    private var player: AVPlayer?
    @Published var isPlaying = false

    func play(url: String) {
        guard let u = URL(string: url) else { return }
        player?.pause()
        player = AVPlayer(url: u)
        player?.allowsExternalPlayback = true
        player?.play()
        isPlaying = true
    }

    func pause() { player?.pause(); isPlaying = false }
    func resume() { player?.play(); isPlaying = true }
}

// MARK: - Track Scraper WebView

struct TrackScraperWebView: NSViewRepresentable {
    let url: URL
    let onTracksFound: ([BandcampTrack]) -> Void
    let onURLClick: (URL) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: url))
        context.coordinator.webView = wv
        context.coordinator.parent = self
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        // Reload when URL changes
        if wv.url != url {
            wv.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        var webView: WKWebView?
        var parent: TrackScraperWebView?

        func webView(_ wv: WKWebView, didFinish navigation: WKNavigation!) {
            // Wait for dynamic content to render, then scrape
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.scrapeTracks(wv)
            }
        }

        func scrapeTracks(_ wv: WKWebView) {
            // Since we loaded the API URL directly, the page body is JSON
            let js = "document.body.innerText"
            wv.evaluateJavaScript(js) { result, _ in
                guard let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    DispatchQueue.main.async { self.parent?.onTracksFound([]) }
                    return
                }

                var tracks: [BandcampTrack] = []
                if let items = json["items"] as? [[String: Any]] {
                    for item in items {
                        let title = item["item_title"] as? String ?? ""
                        let artist = item["band_name"] as? String ?? ""
                        let artID = item["item_art_id"] as? Int ?? 0
                        let artURL = artID > 0 ? "https://f4.bcbits.com/img/a\(artID)_2.jpg" : ""
                        let dur = item["track_duration"] as? Double ?? 0
                        let mins = Int(dur) / 60
                        let secs = Int(dur) % 60
                        let duration = "\(mins):\(String(format: "%02d", secs))"
                        var streamURL = ""
                        if let redl = json["redownload_urls"] as? [String: Any],
                           let urls = redl[String(item["item_id"] as? Int ?? 0)] as? [String: Any] {
                            streamURL = (urls["mp3-128"] as? String) ?? ""
                        }
                        if !title.isEmpty {
                            tracks.append(BandcampTrack(title: title, artist: artist, album: "", streamURL: streamURL, artURL: artURL, duration: duration))
                        }
                    }
                }
                DispatchQueue.main.async { self.parent?.onTracksFound(tracks) }
            }
        }
    }
}
