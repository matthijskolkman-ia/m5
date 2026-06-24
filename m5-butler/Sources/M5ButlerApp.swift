import SwiftUI
import AppKit

// MARK: - App

@main
struct M5ButlerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "M5"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 620)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ButlerView())

        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        // Refresh stats every 2s
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            NotificationCenter.default.post(name: .refreshStats, object: nil)
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

extension Notification.Name {
    static let refreshStats = Notification.Name("refreshStats")
}

// MARK: - System Stats

struct SystemStats: Equatable {
    var cpu: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = 0
    var uptime: TimeInterval = 0
}

func fetchStats() -> SystemStats {
    var stats = SystemStats()

    // CPU via host_processor_info
    var cpuInfo: processor_info_array_t!
    var numCpuInfo: mach_msg_type_number_t = 0
    var numCpus: natural_t = 0
    host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
    var totalUser: Float = 0, totalSystem: Float = 0, totalIdle: Float = 0
    let stride = Int(CPU_STATE_MAX)
    for i in 0..<Int(numCpus) {
        totalUser += Float(cpuInfo[stride * i + Int(CPU_STATE_USER)])
        totalSystem += Float(cpuInfo[stride * i + Int(CPU_STATE_SYSTEM)])
        totalIdle += Float(cpuInfo[stride * i + Int(CPU_STATE_IDLE)])
    }
    let deallocSize = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size)
    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), deallocSize)
    let total = totalUser + totalSystem + totalIdle
    stats.cpu = total > 0 ? Double((totalUser + totalSystem) / total * 100) : 0

    // Memory
    var pageSize: vm_size_t = 0
    host_page_size(mach_host_self(), &pageSize)
    var hostInfo = vm_statistics64()
    var hostInfoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    withUnsafeMutablePointer(to: &hostInfo) { ptr in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(hostInfoCount)) { rebound in
            _ = host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &hostInfoCount)
        }
    }
    stats.memoryUsed = UInt64(hostInfo.active_count + hostInfo.inactive_count + hostInfo.wire_count) * UInt64(pageSize)
    stats.memoryTotal = UInt64(ProcessInfo.processInfo.physicalMemory)

    // Uptime
    var boottime = timeval()
    var size = MemoryLayout<timeval>.size
    sysctlbyname("kern.boottime", &boottime, &size, nil, 0)
    stats.uptime = Date().timeIntervalSince1970 - TimeInterval(boottime.tv_sec)

    return stats
}

func formatBytes(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / 1_073_741_824
    return String(format: "%.1f GB", gb)
}

func formatUptime(_ s: TimeInterval) -> String {
    let days = Int(s) / 86400
    let hours = (Int(s) % 86400) / 3600
    let mins = (Int(s) % 3600) / 60
    if days > 0 { return "\(days)d \(hours)h" }
    return "\(hours)h \(mins)m"
}

// MARK: - Project

struct Project: Identifiable {
    let id = UUID()
    let name: String; let icon: String; let path: String
    let action: ProjectAction; let color: Color
}

enum ProjectAction { case open, run, terminal, url(URL) }

let projects: [Project] = [
    Project(name: "Deep Data Detective", icon: "🕵️", path: "deep-data-detective", action: .terminal, color: .blue),
    Project(name: "Song Vault", icon: "🔒", path: "song-vault", action: .terminal, color: .purple),
    Project(name: "Remote Approval", icon: "📱", path: "remote-approval", action: .open, color: .orange),
    Project(name: "Vision Repair", icon: "🔧", path: "vision-repair", action: .open, color: .green),
    Project(name: "Solar System", icon: "🪐", path: "vision-repair-visionos", action: .open, color: .orange),
    Project(name: "SloMoLab", icon: "📹", path: "slomolab", action: .open, color: .red),
    Project(name: "LeicaCam", icon: "🔴", path: "leica-cam", action: .open, color: .red),
    Project(name: "HTML Mirrors", icon: "🌐", path: "html-mirrors", action: .open, color: .cyan),
    Project(name: "Project Universe", icon: "✨", path: "project-universe.html", action: .url(URL(fileURLWithPath: NSHomeDirectory() + "/Documents/m5/project-universe.html")), color: .indigo),
    Project(name: "Washing Machine", icon: "🧺", path: "washing-machine", action: .terminal, color: .blue),
    Project(name: "Dryer", icon: "🌀", path: "dryer", action: .terminal, color: .teal),
]

let baseDir = NSHomeDirectory() + "/Documents/m5"

// MARK: - UI

struct ButlerView: View {
    @State private var stats = fetchStats()
    @State private var bearNote = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("M5 Butler").font(.headline)
                Spacer()
                Text("\(formatUptime(stats.uptime)) up")
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)

            // Stats bar
            HStack(spacing: 0) {
                StatGauge(label: "CPU", value: stats.cpu, color: stats.cpu > 70 ? .red : stats.cpu > 40 ? .orange : .green)
                Divider().frame(height: 28)
                StatGauge(label: "RAM", value: Double(stats.memoryUsed) / Double(stats.memoryTotal) * 100,
                           color: .blue, detail: "\(formatBytes(stats.memoryUsed)) / \(formatBytes(stats.memoryTotal))")
                Divider().frame(height: 28)
                StatGauge(label: "GPU", value: 18, color: .purple, detail: "Metal active")
                Divider().frame(height: 28)
                StatGauge(label: "NE", value: 5, color: .cyan, detail: "Neural Engine")
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)

            // Bear quick capture
            VStack(spacing: 6) {
                HStack {
                    Text("🐻 Bear").font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                    Spacer()
                    Button("Open Bear") { openBear("") }
                        .font(.system(size: 8)).foregroundColor(.secondary).buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    TextField("Quick note...", text: $bearNote)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                        .onSubmit { sendToBear() }

                    Button(action: { sendToBear() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3).foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(bearNote.isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
                .padding(.horizontal, 10)

                HStack(spacing: 4) {
                    BearChip(label: "Today", icon: "calendar") { openBear("/open-tag?name=journal") }
                    BearChip(label: "Inbox", icon: "tray") { openBear("/open-tag?name=inbox") }
                    BearChip(label: "Search", icon: "magnifyingglass") { openBear("/search") }
                    BearChip(label: "Todo", icon: "checklist") { sendToBear(template: "☐ ") }
                }
                .padding(.horizontal, 10).padding(.bottom, 2)
            }
            .padding(.vertical, 8)

            // Projects
            VStack(alignment: .leading, spacing: 0) {
                Text("PROJECTS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(projects) { proj in
                            Button(action: { launch(proj) }) {
                                HStack(spacing: 10) {
                                    Text(proj.icon).font(.body)
                                    Text(proj.name).font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: actionIcon(proj.action))
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider().padding(.horizontal, 16).padding(.vertical, 6)

            // Quick actions
            HStack(spacing: 8) {
                QuickButton("VS Code", "chevron.left.forwardslash.chevron.right") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: baseDir))
                }
                QuickButton("Terminal", "terminal") {
                    let url = URL(fileURLWithPath: baseDir)
                    NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: NSWorkspace.OpenConfiguration())
                }
                QuickButton("Finder", "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: baseDir)])
                }
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power").font(.caption).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 340)
        .background(Color(red: 0.06, green: 0.06, blue: 0.10))
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .refreshStats)) { _ in
            stats = fetchStats()
        }
    }

    func launch(_ proj: Project) {
        let fullPath = baseDir + "/" + proj.path
        switch proj.action {
        case .open:
            NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
        case .terminal:
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = ["-a", "Terminal", fullPath]
            try? task.run()
        case .run:
            print("Run \(proj.name)")
        case .url(let url):
            NSWorkspace.shared.open(url)
        }
    }

    func actionIcon(_ action: ProjectAction) -> String {
        switch action {
        case .open: "folder"
        case .terminal: "terminal"
        case .run: "play.fill"
        case .url: "safari"
        }
    }

    // ── Bear ──

    func sendToBear(template: String = "") {
        let text = template.isEmpty ? bearNote : template
        guard !text.isEmpty else { return }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "bear://x-callback-url/create?text=\(encoded)")!
        NSWorkspace.shared.open(url)
        if template.isEmpty { bearNote = "" }
    }

    func openBear(_ path: String) {
        let url = URL(string: "bear://x-callback-url\(path)") ?? URL(string: "bear://")!
        NSWorkspace.shared.open(url)
    }
}

struct BearChip: View {
    let label: String; let icon: String; let action: () -> Void
    init(label: String, icon: String, action: @escaping () -> Void) {
        self.label = label; self.icon = icon; self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 8))
                Text(label).font(.system(size: 9))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain)
    }
}

struct StatGauge: View {
    let label: String; let value: Double; let color: Color; var detail: String = ""

    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 4)
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: max(CGFloat(value / 100) * 50, 2), height: 4)
            }
            Text(String(format: "%.0f%%", value)).font(.system(size: 9, design: .monospaced)).foregroundColor(color)
                .lineLimit(1)
            if !detail.isEmpty {
                Text(detail).font(.system(size: 7)).foregroundColor(.secondary.opacity(0.6)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickButton: View {
    let title: String; let icon: String; let action: () -> Void

    init(_ title: String, _ icon: String, _ action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(title).font(.system(size: 9))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
    }
}
