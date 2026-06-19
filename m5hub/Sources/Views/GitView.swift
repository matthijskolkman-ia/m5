import SwiftUI

struct GitView: View {
    @StateObject private var gh = GitHubService()
    @State private var usernameInput = UserDefaults.standard.string(forKey: "github_user") ?? ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Username input
                    HStack {
                        TextField("GitHub username", text: $usernameInput)
                            .textFieldStyle(.roundedBorder).font(.subheadline)
                            .autocapitalization(.none)
                        Button("Fetch") {
                            UserDefaults.standard.set(usernameInput, forKey: "github_user")
                            gh.fetchContributions(for: usernameInput)
                        }
                        .font(.subheadline).buttonStyle(.borderedProminent)
                        .disabled(usernameInput.isEmpty || gh.isLoading)
                    }.padding(.horizontal)

                    if gh.isLoading {
                        ProgressView()
                    }

                    if let err = gh.error {
                        Text(err).font(.caption).foregroundColor(.orange)
                    }

                    // Stats cards
                    if !gh.username.isEmpty {
                        HStack(spacing: 12) {
                            statCard(title: "Streak", value: "\(gh.streakDays)d", color: .orange)
                            statCard(title: "Today", value: "\(gh.todayCount)", color: gh.todayCount > 0 ? .green : .gray)
                            statCard(title: "Year", value: "\(gh.totalContribs)", color: .blue)
                        }.padding(.horizontal)
                    }

                    // Contribution grid
                    if !gh.contribDays.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 20), spacing: 2) {
                            ForEach(gh.contribDays.prefix(280)) { day in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(contribColor(day.level))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }.padding(.horizontal)
                    }

                    // Repo status (hardcoded to m5)
                    if !gh.username.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repositories").font(.headline).foregroundColor(.white)
                            HStack {
                                Image(systemName: "arrow.triangle.branch").font(.caption)
                                Text("matthijskolkman-ia/m5")
                                    .font(.caption).foregroundColor(.blue)
                                Spacer()
                                Circle()
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: 6, height: 6)
                                Text("synced").font(.caption2).foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }.padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("GitHub")
            .onAppear {
                if !usernameInput.isEmpty {
                    gh.fetchContributions(for: usernameInput)
                }
            }
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold()).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    private func contribColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.15)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        default: return Color.green.opacity(0.9)
        }
    }
}
