import Foundation

struct NewsItem: Identifiable {
    let id = UUID()
    var title: String = ""
    var source: String = ""
    var url: String = ""
    var publishedAt: String = ""
}

class NewsService: ObservableObject {
    @Published var articles: [NewsItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "newsapi_key") ?? ""
    }

    func fetch() {
        guard !apiKey.isEmpty else { error = "Set NewsAPI key in Settings"; return }
        isLoading = true; error = nil

        // Top headlines, US, 10 results
        guard let url = URL(string: "https://newsapi.org/v2/top-headlines?country=us&pageSize=10&apiKey=\(apiKey)") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let articles = json["articles"] as? [[String:Any]] else {
                DispatchQueue.main.async { self?.isLoading = false; self?.error = "Failed to load news" }; return
            }
            let items: [NewsItem] = articles.prefix(10).map { a in
                NewsItem(
                    title: a["title"] as? String ?? "",
                    source: (a["source"] as? [String:Any])?["name"] as? String ?? "",
                    url: a["url"] as? String ?? "",
                    publishedAt: String((a["publishedAt"] as? String ?? "").prefix(10))
                )
            }
            DispatchQueue.main.async { self.articles = items; self.isLoading = false }
        }.resume()
    }
}
