import SwiftUI
import WebKit
import AppKit

struct MixcldWebView: NSViewRepresentable {
    let url: URL
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var pageTitle: String
    @Binding var currentURL: String

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: url))
        context.coordinator.webView = wv
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        if wv.url != url { wv.load(URLRequest(url: url)) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: MixcldWebView
        var webView: WKWebView?
        init(_ p: MixcldWebView) { self.parent = p }
        func webView(_ wv: WKWebView, didFinish navigation: WKNavigation!) {
            parent.canGoBack = wv.canGoBack
            parent.canGoForward = wv.canGoForward
            parent.pageTitle = wv.title ?? "Mixcloud"
            parent.currentURL = wv.url?.absoluteString ?? ""
        }
    }
}

struct MixcldView: View {
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var pageTitle = "Mixcloud"
    @State private var currentURL = ""
    @State private var browserURL = URL(string: "https://www.mixcloud.com")!
    @State private var wvRef: MixcldWebView.Coordinator?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "radio.fill")
                    .font(.system(size: 13)).foregroundColor(.purple)
                Text("Mixcld")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()

                HStack(spacing: 4) {
                    Button(action: { wvRef?.webView?.goBack() }) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                            .foregroundColor(canGoBack ? .white.opacity(0.7) : .white.opacity(0.2))
                    }.buttonStyle(.plain).disabled(!canGoBack)

                    Button(action: { wvRef?.webView?.goForward() }) {
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                            .foregroundColor(canGoForward ? .white.opacity(0.7) : .white.opacity(0.2))
                    }.buttonStyle(.plain).disabled(!canGoForward)

                    Button(action: { wvRef?.webView?.reload() }) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }.buttonStyle(.plain)

                    Button(action: { browserURL = URL(string: "https://www.mixcloud.com")! }) {
                        Image(systemName: "house.fill").font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(red: 0.06, green: 0.06, blue: 0.10))

            Divider().background(Color.white.opacity(0.06))

            // Quick nav buttons
            HStack(spacing: 6) {
                ForEach(["feed","popular","categories","upload"], id: \.self) { page in
                    Button(page.capitalized) {
                        browserURL = URL(string: "https://www.mixcloud.com/\(page)/")!
                    }
                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(pageTitle).font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.2)).lineLimit(1)
            }.padding(.horizontal, 10).padding(.vertical, 3)

            Divider().background(Color.white.opacity(0.04))

            MixcldWebView(
                url: browserURL, canGoBack: $canGoBack,
                canGoForward: $canGoForward, pageTitle: $pageTitle,
                currentURL: $currentURL
            )
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
    }
}
