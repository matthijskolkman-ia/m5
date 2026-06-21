import SwiftUI

struct NewsView: View {
    @ObservedObject var service: NewsService

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "newspaper.fill").font(.system(size: 13)).foregroundColor(.purple)
                Text("News").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                if service.isLoading { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
                Button(action: { service.fetch() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 14).padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.05))

            if let err = service.error {
                VStack(spacing: 8) {
                    Text(err).font(.caption).foregroundColor(.orange).padding(.top, 20)
                    Text("Get a free key at newsapi.org").font(.caption2).foregroundColor(.gray)
                }
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.articles) { article in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title)
                                .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(3)
                            HStack {
                                Text(article.source).font(.system(size: 8)).foregroundColor(.purple.opacity(0.6))
                                Text("·").foregroundColor(.gray)
                                Text(article.publishedAt).font(.system(size: 8)).foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        Divider().background(Color.white.opacity(0.03)).padding(.leading, 14)
                    }
                }
            }
        }
    }
}
