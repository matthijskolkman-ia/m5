import SwiftUI

// MARK: - GitHub Scraper

final class StreakFetcher: ObservableObject {
    @Published var username: String = ""
    @Published var streakDays: Int = 0
    @Published var todayCount: Int = 0
    @Published var yearDays: [DayContrib] = []
    @Published var totalContribs: Int = 0
    @Published var isLoading = false
    @Published var error: String?

    struct DayContrib: Identifiable {
        let id = UUID()
        let date: String
        let count: Int
        let level: Int // 0-4
    }

    func fetch(for user: String) {
        username = user
        isLoading = true
        error = nil

        // GitHub serves contributions at /users/<user>/contributions as HTML
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

        // Extract data-date and data-level from <td> elements
        let tdPattern = #"data-date="(\d{4}-\d{2}-\d{2})"[^>]*data-level="(\d)""#
        guard let tdRegex = try? NSRegularExpression(pattern: tdPattern) else { return }

        var dates: [(String, Int, NSRange)] = [] // (date, level, range)
        let tdRange = NSRange(html.startIndex..<html.endIndex, in: html)
        tdRegex.enumerateMatches(in: html, range: tdRange) { match, _, _ in
            guard let match,
                  let dRange = Range(match.range(at: 1), in: html),
                  let lRange = Range(match.range(at: 2), in: html)
            else { return }
            dates.append((String(html[dRange]), Int(html[lRange]) ?? 0, match.range))
        }

        // Extract tooltip counts: "N contributions on Date." or "No contributions on Date."
        let tipPattern = #"for="contribution-day-component[^"]*"[^>]*>\s*(?:(\d+)\s+contributions?|No\s+contribution)"#
        guard let tipRegex = try? NSRegularExpression(pattern: tipPattern) else { return }

        var tipCounts: [Int] = []
        let tipRange = NSRange(html.startIndex..<html.endIndex, in: html)
        tipRegex.enumerateMatches(in: html, range: tipRange) { match, _, _ in
            guard let match else { return }
            if let cRange = Range(match.range(at: 1), in: html) {
                tipCounts.append(Int(html[cRange]) ?? 0)
            } else {
                tipCounts.append(0)
            }
        }

        // Pair dates with counts (they appear in the same order)
        for i in 0..<min(dates.count, tipCounts.count) {
            days.append((dates[i].0, tipCounts[i], dates[i].1))
        }

        // Calculate streak
        days.sort { $0.date > $1.date }
        var streak = 0
        let calendar = Calendar.current

        for day in days {
            guard let d = ISO8601DateFormatter().date(from: day.date + "T00:00:00Z") else { continue }
            let expected = calendar.date(byAdding: .day, value: -streak, to: Date()) ?? Date()
            if calendar.isDate(d, inSameDayAs: expected) && day.count > 0 {
                streak += 1
            } else if calendar.isDate(d, inSameDayAs: Date()) {
                if day.count > 0 { streak += 1 }
            } else if calendar.isDate(d, inSameDayAs: calendar.date(byAdding: .day, value: 0, to: Date()) ?? Date()) {
                // today already counted
            } else {
                break
            }
        }

        // Today's count
        let todayStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let todayContrib = days.first(where: { $0.date == todayStr })

        // All days for full grid (last 365)
        let allDays = days.sorted { $0.date > $1.date }
        let totalCount = days.reduce(0) { $0 + $1.count }

        DispatchQueue.main.async {
            self.streakDays = streak
            self.todayCount = todayContrib?.count ?? 0
            self.totalContribs = totalCount
            self.yearDays = allDays.map { DayContrib(date: $0.date, count: $0.count, level: $0.level) }
            self.isLoading = false
            if days.isEmpty { self.error = "No contribution data found" }
        }
    }
}

// MARK: - Main View

struct StreakView: View {
    @StateObject private var fetcher = StreakFetcher()
    @State private var userInput = ""
    @AppStorage("ghUser") private var savedUser = ""

    let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11)).foregroundColor(streakColor)
                Text("GitStreak")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if fetcher.isLoading {
                    ProgressView().scaleEffect(0.4)
                }
                Text("@\(fetcher.username)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }.padding(.horizontal, 10).padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.06))

            // Streak number
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(fetcher.streakDays)")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(streakColor)
                Text("days")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TODAY")
                        .font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.2))
                    Text("\(fetcher.todayCount)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(fetcher.todayCount > 0 ? .green : .white.opacity(0.3))
                    Text("commits")
                        .font(.system(size: 7)).foregroundColor(.white.opacity(0.2))
                }
            }.padding(.horizontal, 10).padding(.vertical, 6)

            // Mini chart — last 7 days
            if !fetcher.yearDays.isEmpty {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(fetcher.yearDays.prefix(7))) { day in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(contribColor(day.level))
                                .frame(width: 10, height: max(2, CGFloat(day.level + 1) * 6))
                            Text(day.date)
                                .font(.system(size: 6, design: .monospaced))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                }.padding(.horizontal, 16).padding(.vertical, 4)
            }

            Spacer()

            // Input bar
            HStack(spacing: 4) {
                TextField("GitHub username", text: $userInput)
                    .textFieldStyle(.plain).font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .onSubmit { lookup() }
                Button(action: lookup) {
                    Text("Go")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.green.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 10).padding(.bottom, 6)

            if let err = fetcher.error {
                Text(err).font(.system(size: 7)).foregroundColor(.red.opacity(0.6))
                    .padding(.bottom, 4)
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
        .onAppear {
            if !savedUser.isEmpty { userInput = savedUser; lookup() }
        }
        .onReceive(timer) { _ in
            if !fetcher.username.isEmpty { fetcher.fetch(for: fetcher.username) }
        }
    }

    func lookup() {
        let u = userInput.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty else { return }
        savedUser = u
        fetcher.fetch(for: u)
    }

    var streakColor: Color {
        if fetcher.streakDays >= 100 { return .orange }
        if fetcher.streakDays >= 30 { return .yellow }
        if fetcher.streakDays > 0 { return .green }
        return .white.opacity(0.2)
    }

    func contribColor(_ level: Int) -> Color {
        switch level {
        case 0: return .white.opacity(0.06)
        case 1: return .green.opacity(0.25)
        case 2: return .green.opacity(0.45)
        case 3: return .green.opacity(0.7)
        case 4: return .green.opacity(0.9)
        default: return .white.opacity(0.06)
        }
    }
}
