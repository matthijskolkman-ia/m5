import SwiftUI

// MARK: - Git Status Model

struct GitStatus {
    var branch: String = "—"
    var ahead: Int = 0
    var behind: Int = 0
    var unstaged: Int = 0
    var staged: Int = 0
    var untracked: Int = 0
    var lastCommit: String = "—"
    var lastCommitMsg: String = "—"
    var error: String?
    var isRepo: Bool = true

    var needsPush: Bool { ahead > 0 || unstaged > 0 || staged > 0 || untracked > 0 }
    var dirtyCount: Int { unstaged + staged + untracked }
    var allClean: Bool { !needsPush && behind == 0 }
}

// MARK: - Git Service

final class GitSync: ObservableObject {
    @Published var status = GitStatus()
    @Published var repoPath: String
    @Published var isRunning = false
    @Published var outputLog: String = ""

    private let dir: String

    init(repoPath: String) {
        self.repoPath = repoPath
        self.dir = repoPath
        refresh()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let s = self.readStatus()
            DispatchQueue.main.async { self.status = s }
        }
    }

    func commitAndPush(message: String) {
        isRunning = true
        outputLog = ""
        DispatchQueue.global(qos: .userInitiated).async {
            var log = ""

            // Add all
            let add = shell("git", "-C", self.dir, "add", "-A")
            log += add.out
            if add.code != 0 { log += "⚠️ add failed\n" }

            // Commit
            let cmt = shell("git", "-C", self.dir, "commit", "-m", message)
            log += cmt.out
            if cmt.code != 0 {
                if cmt.out.contains("nothing to commit") {
                    log += "Nothing to commit\n"
                } else {
                    log += "⚠️ commit failed\n"
                }
            }

            // Push
            let push = shell("git", "-C", self.dir, "push")
            log += push.out
            if push.code != 0 {
                log += "⚠️ push failed\n"
            }

            DispatchQueue.main.async {
                self.outputLog = log.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isRunning = false
                self.refresh()
            }

            // Auto-hide success log after 8s
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                if self.outputLog == log.trimmingCharacters(in: .whitespacesAndNewlines) {
                    self.outputLog = ""
                }
            }
        }
    }

    private func readStatus() -> GitStatus {
        var s = GitStatus()

        // Check if it's a git repo
        let check = shell("git", "-C", dir, "rev-parse", "--is-inside-work-tree")
        if check.code != 0 {
            s.isRepo = false
            s.error = "Not a git repository"
            return s
        }

        // Branch
        let branch = shell("git", "-C", dir, "branch", "--show-current")
        s.branch = branch.out.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ahead/behind
        let ab = shell("git", "-C", dir, "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
        if ab.code == 0 {
            let parts = ab.out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
            if parts.count == 2 {
                s.behind = Int(parts[0]) ?? 0
                s.ahead = Int(parts[1]) ?? 0
            }
        }

        // Staged
        let staged = shell("git", "-C", dir, "diff", "--cached", "--name-only")
        if staged.code == 0 {
            s.staged = staged.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 :
                staged.out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").count
        }

        // Unstaged
        let unstaged = shell("git", "-C", dir, "diff", "--name-only")
        if unstaged.code == 0 {
            s.unstaged = unstaged.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 :
                unstaged.out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").count
        }

        // Untracked
        let untracked = shell("git", "-C", dir, "ls-files", "--others", "--exclude-standard")
        if untracked.code == 0 {
            s.untracked = untracked.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 :
                untracked.out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").count
        }

        // Last commit
        let lastHash = shell("git", "-C", dir, "log", "-1", "--format=%h")
        s.lastCommit = lastHash.out.trimmingCharacters(in: .whitespacesAndNewlines)

        let lastMsg = shell("git", "-C", dir, "log", "-1", "--format=%s")
        s.lastCommitMsg = lastMsg.out.trimmingCharacters(in: .whitespacesAndNewlines)

        return s
    }
}

// MARK: - Shell Helper

func shell(_ args: String...) -> (code: Int32, out: String) {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    } catch {
        return (-1, error.localizedDescription)
    }
}

// MARK: - View

struct SyncView: View {
    @StateObject private var sync = GitSync(repoPath: NSHomeDirectory() + "/Documents/m5")
    @State private var commitMsg: String = "backup \(ISO8601DateFormatter().string(from: Date()).prefix(19))"
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14)).foregroundColor(.green)
                Text("GitSync")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Button(action: { sync.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }.buttonStyle(.plain).disabled(sync.isRunning)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(red: 0.06, green: 0.06, blue: 0.10))

            Divider().background(Color.white.opacity(0.06))

            // Status cards
            VStack(spacing: 6) {
                // Repo info
                HStack {
                    Circle()
                        .fill(sync.status.allClean ? Color.green.opacity(0.8) :
                              sync.status.needsPush ? Color.orange.opacity(0.8) : Color.red.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text(sync.status.isRepo ? "m5" : "No repo")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(sync.status.branch)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(3)
                }

                if sync.status.isRepo {
                    statusRow(icon: "arrow.up", label: "Ahead", value: "\(sync.status.ahead)", color: sync.status.ahead > 0 ? Color.green : Color.white.opacity(0.3))
                    statusRow(icon: "arrow.down", label: "Behind", value: "\(sync.status.behind)", color: sync.status.behind > 0 ? Color.yellow : Color.white.opacity(0.3))
                    statusRow(icon: "plus.circle", label: "Staged", value: "\(sync.status.staged)", color: sync.status.staged > 0 ? Color.cyan : Color.white.opacity(0.3))
                    statusRow(icon: "pencil.circle", label: "Modified", value: "\(sync.status.unstaged)", color: sync.status.unstaged > 0 ? Color.orange : Color.white.opacity(0.3))
                    statusRow(icon: "questionmark.circle", label: "Untracked", value: "\(sync.status.untracked)", color: sync.status.untracked > 0 ? Color.purple : Color.white.opacity(0.3))

                    Divider().background(Color.white.opacity(0.04))

                    // Last commit
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last commit")
                            .font(.system(size: 8)).foregroundColor(.white.opacity(0.25))
                        Text("\(sync.status.lastCommit) — \(sync.status.lastCommitMsg)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else if let err = sync.status.error {
                    Text(err).font(.system(size: 10)).foregroundColor(.red.opacity(0.7))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.06))

            // Commit message
            VStack(spacing: 4) {
                TextField("Commit message", text: $commitMsg)
                    .textFieldStyle(.plain).font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(4)
            }.padding(.horizontal, 12).padding(.vertical, 8)

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    if sync.status.needsPush {
                        sync.commitAndPush(message: commitMsg.isEmpty ? "backup" : commitMsg)
                    }
                }) {
                    HStack(spacing: 4) {
                        if sync.isRunning {
                            ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "icloud.and.arrow.up.fill").font(.system(size: 10))
                        }
                        Text(sync.isRunning ? "Pushing..." : "Push to GitHub")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(sync.status.needsPush && !sync.isRunning ? Color.green : Color.gray.opacity(0.4))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(!sync.status.needsPush || sync.isRunning)

                Button(action: { showLog.toggle() }) {
                    Image(systemName: showLog ? "chevron.up" : "terminal")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.bottom, 6)

            // Output log
            if showLog && !sync.outputLog.isEmpty {
                ScrollView {
                    Text(sync.outputLog)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
                .padding(.horizontal, 12).padding(.bottom, 8)
            }

            // Auto-refresh hint
            HStack {
                Text("Refreshes on open • Pull manually via terminal")
                    .font(.system(size: 7)).foregroundColor(.white.opacity(0.15))
                Spacer()
            }.padding(.horizontal, 12).padding(.bottom, 6)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .onAppear { sync.refresh() }
    }

    func statusRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(color).frame(width: 14)
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
            Spacer()
            Text(value).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(color)
        }
    }
}
