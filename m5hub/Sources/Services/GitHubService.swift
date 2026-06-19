import Foundation

struct GitHubContribDay: Identifiable {
    let id = UUID()
    let date: String
    let count: Int
    let level: Int
}

struct GitHubRepoStatus {
    var name: String = ""
    var branch: String = ""
    var pushed: Bool = true
    var commitCount: Int = 0
    var lastPush: String = ""
}

class GitHubService: ObservableObject {
    @Published var contribDays: [GitHubContribDay] = []
    @Published var totalContribs: Int = 0
    @Published var streakDays: Int = 0
    @Published var todayCount: Int = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var username: String = ""

    func fetchContributions(for user: String) {
        username = user
        isLoading = true
        error = nil

        guard let url = URL(string: "https://github.com/users/\(user)/contributions") else { return }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15

        URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
            guard let self, let data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self?.isLoading = false; self?.error = "Could not reach GitHub" }
                return
            }
            self.parseHTML(html)
        }.resume()
    }

    private func parseHTML(_ html: String) {
        var days: [(date: String, count: Int, level: Int)] = []
        let pattern = #"data-date="(\d{4}-\d{2}-\d{2})"[^>]*data-level="(\d)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let m = match, m.numberOfRanges == 3,
                  let dateRange = Range(m.range(at: 1), in: html),
                  let levelRange = Range(m.range(at: 2), in: html) else { return }
            let date = String(html[dateRange])
            let level = Int(html[levelRange]) ?? 0

            // Count from text between >count<
            if let countStart = html.range(of: ">", options: [], range: m.range.upperBound..<html.index(m.range.upperBound, offsetBy: 20)),
               let countEnd = html.range(of: "<", range: countStart.upperBound..<html.index(countStart.upperBound, offsetBy: 20)) {
                let countStr = String(html[countStart.upperBound..<countEnd.lowerBound])
                let count = countStr.contains("No") ? 0 : (Int(countStr.filter { $0.isNumber }) ?? 0)
                days.append((date, count, level))
            } else {
                days.append((date, 0, level))
            }
        }

        // Today
        let todayStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let todayContrib = days.first(where: { $0.date == todayStr })
        let total = days.reduce(0) { $0 + $1.count }

        // Streak: count consecutive days from today backwards
        var streak = 0
        let sorted = days.sorted { $0.date > $1.date }
        for day in sorted {
            if day.count > 0 { streak += 1 } else { break }
        }

        let contribDays = sorted.map { GitHubContribDay(date: $0.date, count: $0.count, level: $0.level) }

        DispatchQueue.main.async {
            self.contribDays = contribDays
            self.totalContribs = total
            self.streakDays = streak
            self.todayCount = todayContrib?.count ?? 0
            self.isLoading = false
            if days.isEmpty { self.error = "No contribution data found" }
        }
    }
}
