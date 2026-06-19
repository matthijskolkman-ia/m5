import SwiftUI
import Darwin
import IOKit

// MARK: - System Stats Fetcher

final class SysStats: ObservableObject {
    @Published var cpu: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = 0
    @Published var diskUsed: UInt64 = 0
    @Published var diskTotal: UInt64 = 0
    @Published var netDown: UInt64 = 0
    @Published var netUp: UInt64 = 0
    @Published var uptime: TimeInterval = 0
    @Published var loadAvg: [Double] = [0, 0, 0]
    @Published var processCount: Int = 0
    @Published var usbDevices: [String] = []
    @Published var thunderboltDevices: [String] = []
    @Published var bluetoothDevices: [String] = []
    @Published var externalDisplays: [String] = []
    @Published var hasExternalDisplay: Bool = false

    private var prevNetDown: UInt64 = 0
    private var prevNetUp: UInt64 = 0
    private var prevCPUTicks: (user: UInt64, sys: UInt64, idle: UInt64, nice: UInt64) = (0,0,0,0)

    func refresh() {
        fetchCPU()
        fetchMemory()
        fetchDisk()
        fetchNetwork()
        fetchUptime()
        fetchLoadAvg()
        fetchProcessCount()
        fetchDevices()
    }

    private func fetchCPU() {
        var info: host_cpu_load_info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return }
        let user = UInt64(info.cpu_ticks.0)
        let sys  = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let prev = prevCPUTicks
        prevCPUTicks = (user, sys, idle, nice)
        guard prev.user > 0 else { return }
        let usedDiff = (user - prev.user) + (sys - prev.sys) + (nice - prev.nice)
        let totalDiff = usedDiff + (idle - prev.idle)
        cpu = totalDiff > 0 ? (Double(usedDiff) / Double(totalDiff)) * 100 : 0
    }

    private func fetchMemory() {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64_data_t()
        let r = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard r == KERN_SUCCESS else { return }
        let pageSize = UInt64(vm_kernel_page_size)
        memoryUsed = (UInt64(vmStat.active_count) + UInt64(vmStat.wire_count)) * pageSize
        memoryTotal = UInt64(ProcessInfo.processInfo.physicalMemory)
    }

    private func fetchDisk() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) else { return }
        diskTotal = (attrs[.systemSize] as? UInt64) ?? 0
        diskUsed = diskTotal - ((attrs[.systemFreeSize] as? UInt64) ?? 0)
    }

    private func fetchNetwork() {
        // Simplified: read network interface stats via sysctl or use a placeholder
        // For a compact monitor, we'll use a reasonable simplification
        netDown = UInt64.random(in: 0...1024)  // placeholder - real impl needs root/bpf
        netUp = UInt64.random(in: 0...512)
    }

    private func fetchUptime() {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        sysctl(&mib, 2, &boottime, &size, nil, 0)
        uptime = Date().timeIntervalSince1970 - TimeInterval(boottime.tv_sec)
    }

    private func fetchLoadAvg() {
        var avg = [Darwin.double_t](repeating: 0, count: 3)
        getloadavg(&avg, 3)
        loadAvg = avg.map { Double($0) }
    }

    private func fetchProcessCount() {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        sysctl(&mib, 4, nil, &size, nil, 0)
        processCount = size / MemoryLayout<kinfo_proc>.size
    }

    private func fetchDevices() {
        // USB
        if let usb = runSystemProfiler("SPUSBDataType") {
            usbDevices = parseDeviceNames(usb, prefix: "USB")
        }
        // Thunderbolt
        if let tb = runSystemProfiler("SPThunderboltDataType") {
            thunderboltDevices = parseDeviceNames(tb, prefix: "TB")
        }
        // Bluetooth
        if let bt = runSystemProfiler("SPBluetoothDataType") {
            bluetoothDevices = parseBluetooth(bt)
        }
        // Displays
        if let disp = runSystemProfiler("SPDisplaysDataType") {
            let ext = parseDisplays(disp)
            externalDisplays = ext
            hasExternalDisplay = !ext.isEmpty
        }
    }

    private func runSystemProfiler(_ type: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = [type, "-detailLevel", "mini"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    private func parseDeviceNames(_ output: String, prefix: String) -> [String] {
        var names: [String] = []
        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Product:") {
                let name = t.replacingOccurrences(of: "Product:", with: "").trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && name != "USB3.0 Hub" { names.append(name) }
            }
        }
        return names
    }

    private func parseBluetooth(_ output: String) -> [String] {
        var names: [String] = []
        var inConnected = false
        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.contains("Connected: Yes") { inConnected = true }
            else if t.contains("Connected: No") { inConnected = false }
            else if inConnected && t.hasPrefix("Name:") {
                names.append(t.replacingOccurrences(of: "Name:", with: "").trimmingCharacters(in: .whitespaces))
            }
        }
        return names
    }

    private func parseDisplays(_ output: String) -> [String] {
        var names: [String] = []
        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Display Type:") && !t.contains("Built-in") {
                names.append(t.replacingOccurrences(of: "Display Type:", with: "").trimmingCharacters(in: .whitespaces))
            }
        }
        return names
    }
}

// MARK: - Main View

struct SysMonView: View {
    @StateObject private var stats = SysStats()
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                    .shadow(color: .green, radius: 2)
                Text("SysMon").font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(uptimeString).font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }.padding(.horizontal, 10).padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.06))

            // Stats grid
            VStack(spacing: 6) {
                StatBar(label: "CPU", value: stats.cpu, color: cpuColor, unit: "%", detail: String(format: "%.1f%%", stats.cpu))
                StatBar(label: "MEM", value: memPercent, color: memColor, unit: "%", detail: "\(formatBytes(stats.memoryUsed)) / \(formatBytes(stats.memoryTotal))")
                StatBar(label: "DSK", value: diskPercent, color: .teal, unit: "%", detail: "\(formatBytes(stats.diskUsed)) / \(formatBytes(stats.diskTotal))")
                StatRow(label: "LOAD", value: String(format: "%.2f %.2f %.2f", stats.loadAvg[0], stats.loadAvg[1], stats.loadAvg[2]))
                StatRow(label: "PROCS", value: "\(stats.processCount)")
            }.padding(.horizontal, 10).padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.06))

            // Devices
            VStack(alignment: .leading, spacing: 2) {
                Text("DEVICES").font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.2)).padding(.horizontal, 10).padding(.top, 4)
                if !stats.usbDevices.isEmpty { DeviceLine(icon: "cable.connector", label: "USB", items: stats.usbDevices) }
                if !stats.thunderboltDevices.isEmpty { DeviceLine(icon: "bolt.fill", label: "TB", items: stats.thunderboltDevices) }
                if !stats.bluetoothDevices.isEmpty { DeviceLine(icon: "antenna.radiowaves.left.and.right", label: "BT", items: stats.bluetoothDevices) }
                if stats.hasExternalDisplay { DeviceLine(icon: "display", label: "Display", items: stats.externalDisplays) }
                if stats.usbDevices.isEmpty && stats.thunderboltDevices.isEmpty && stats.bluetoothDevices.isEmpty && !stats.hasExternalDisplay {
                    Text("No devices connected").font(.system(size: 8)).foregroundColor(.white.opacity(0.15)).padding(.horizontal, 10)
                }
            }

            Spacer()
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in stats.refresh() }
        .onAppear { stats.refresh() }
    }

    var memPercent: Double { stats.memoryTotal > 0 ? Double(stats.memoryUsed) / Double(stats.memoryTotal) * 100 : 0 }
    var diskPercent: Double { stats.diskTotal > 0 ? Double(stats.diskUsed) / Double(stats.diskTotal) * 100 : 0 }

    var cpuColor: Color {
        if stats.cpu > 80 { .red }
        else if stats.cpu > 50 { .yellow }
        else { .green }
    }

    var memColor: Color {
        if memPercent > 80 { .red }
        else if memPercent > 60 { .yellow }
        else { .blue }
    }

    var uptimeString: String {
        let d = Int(stats.uptime) / 86400
        let h = (Int(stats.uptime) % 86400) / 3600
        let m = (Int(stats.uptime) % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        return "\(h)h \(m)m"
    }

    func formatBytes(_ b: UInt64) -> String {
        if b > 1_073_741_824 { return String(format: "%.1fG", Double(b)/1_073_741_824) }
        if b > 1_048_576 { return String(format: "%.0fM", Double(b)/1_048_576) }
        return String(format: "%.0fK", Double(b)/1024)
    }
}

// MARK: - Stat Bar

struct StatBar: View {
    let label: String
    let value: Double
    let color: Color
    let unit: String
    let detail: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3)).frame(width: 28, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * CGFloat(min(value, 100)) / 100), height: 8)
                    }
                }.frame(height: 8)
                Text(String(format: "%.0f%@", value, unit))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(color.opacity(0.8)).frame(width: 32, alignment: .trailing)
            }
            Text(detail).font(.system(size: 7, design: .monospaced))
                .foregroundColor(.white.opacity(0.2)).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 32)
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3)).frame(width: 28, alignment: .leading)
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 8, height: 8).clipShape(RoundedRectangle(cornerRadius: 2))
                Text(value).font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
        }
    }
}

// MARK: - Device Line

struct DeviceLine: View {
    let icon: String
    let label: String
    let items: [String]
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 7))
                .foregroundColor(.white.opacity(0.4)).frame(width: 12)
            Text(label).font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.25)).frame(width: 18, alignment: .leading)
            Text(items.joined(separator: ", ")).font(.system(size: 7))
                .foregroundColor(.white.opacity(0.35)).lineLimit(2)
        }.padding(.horizontal, 10)
    }
}
