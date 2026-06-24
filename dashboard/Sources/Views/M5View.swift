import SwiftUI
import AppKit

// MARK: - System Stats

struct SystemStats: Equatable {
    var cpu: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = 0
    var uptime: TimeInterval = 0
}

func fetchStats() -> SystemStats {
    var s = SystemStats()
    var numCpuInfo: mach_msg_type_number_t = 0
    var numCpus: natural_t = 0
    var cpuInfo: processor_info_array_t!
    host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
    var u: Float = 0, sy: Float = 0, id: Float = 0
    let stride = Int(CPU_STATE_MAX)
    for i in 0..<Int(numCpus) { u += Float(cpuInfo[stride*i+Int(CPU_STATE_USER)]); sy += Float(cpuInfo[stride*i+Int(CPU_STATE_SYSTEM)]); id += Float(cpuInfo[stride*i+Int(CPU_STATE_IDLE)]) }
    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo)*vm_size_t(MemoryLayout<integer_t>.size))
    let t = u+sy+id; s.cpu = t>0 ? Double((u+sy)/t*100) : 0
    var ps: vm_size_t = 0; host_page_size(mach_host_self(), &ps)
    var hi = vm_statistics64(); var c = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size/MemoryLayout<integer_t>.size)
    withUnsafeMutablePointer(to: &hi) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(c)) { _=host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &c) } }
    s.memoryUsed = UInt64(hi.active_count+hi.inactive_count+hi.wire_count)*UInt64(ps)
    s.memoryTotal = UInt64(ProcessInfo.processInfo.physicalMemory)
    var bt = timeval(); var sz = MemoryLayout<timeval>.size; sysctlbyname("kern.boottime", &bt, &sz, nil, 0)
    s.uptime = Date().timeIntervalSince1970 - TimeInterval(bt.tv_sec)
    return s
}

func fmtBytes(_ b: UInt64) -> String { String(format: "%.1f GB", Double(b)/1_073_741_824) }
func fmtUp(_ s: TimeInterval) -> String { let d=Int(s)/86400, h=(Int(s)%86400)/3600; return d>0 ? "\(d)d \(h)h" : "\(h)h" }

// MARK: - Project

struct M5Project: Identifiable {
    let id=UUID(); let name:String; let icon:String; let path:String
}

let m5projects: [M5Project] = [
    .init(name:"Deep Data Detective", icon:"🕵️", path:"deep-data-detective"),
    .init(name:"Song Vault", icon:"🔒", path:"song-vault"),
    .init(name:"Remote Approval", icon:"📱", path:"remote-approval"),
    .init(name:"Vision Repair", icon:"🔧", path:"vision-repair"),
    .init(name:"Solar System", icon:"🪐", path:"vision-repair-visionos"),
    .init(name:"SloMoLab", icon:"📹", path:"slomolab"),
    .init(name:"LeicaCam", icon:"🔴", path:"leica-cam"),
    .init(name:"HTML Mirrors", icon:"🌐", path:"html-mirrors"),
    .init(name:"Jukebox", icon:"🎵", path:"jukebox"),
    .init(name:"Washing Machine", icon:"🧺", path:"washing-machine"),
    .init(name:"Dryer", icon:"🌀", path:"dryer"),
]

let m5base = NSHomeDirectory()+"/Documents/m5"

// MARK: - M5 View

struct M5View: View {
    @State private var stats = fetchStats()
    @State private var bearNote = ""
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("M5").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Text("\(fmtUp(stats.uptime)) up")
                        .font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.25))
                }.padding(.horizontal, 14).padding(.top, 10)

                // Stats
                HStack(spacing: 0) {
                    statPill("CPU", stats.cpu, stats.cpu>70 ? .red : stats.cpu>40 ? .orange : .green)
                    statPill("RAM", Double(stats.memoryUsed)/Double(stats.memoryTotal)*100, .blue, "\(fmtBytes(stats.memoryUsed))/\(fmtBytes(stats.memoryTotal))")
                    statPill("GPU", 18, .purple, "Metal")
                    statPill("NE", 5, .cyan, "Neural")
                }.padding(.horizontal, 12)

                // Bear capture
                VStack(alignment: .leading, spacing: 6) {
                    Text("🐻 Bear").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.35))
                    HStack(spacing: 6) {
                        TextField("Quick note...", text: $bearNote)
                            .textFieldStyle(.plain).font(.system(size: 10))
                            .padding(8).background(Color.white.opacity(0.05)).cornerRadius(6)
                            .onSubmit { sendToBear() }
                        Button(action: { sendToBear() }) {
                            Image(systemName: "arrow.up.circle.fill").font(.title3).foregroundColor(.red)
                        }.buttonStyle(.plain).disabled(bearNote.isEmpty)
                    }
                }.padding(.horizontal, 14)

                // Projects
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROJECTS").font(.system(size: 9, weight: .bold)).foregroundColor(.white.opacity(0.35))
                    ForEach(m5projects) { p in
                        Button(action: { openProject(p) }) {
                            HStack(spacing: 8) {
                                Text(p.icon).font(.body)
                                Text(p.name).font(.system(size: 11)).foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.white.opacity(0.2))
                            }.padding(.horizontal, 14).padding(.vertical, 6)
                        }.buttonStyle(.plain)
                    }
                }.padding(.top, 4)

            }.padding(.bottom, 20)
        }
        .onReceive(timer) { _ in stats = fetchStats() }
    }

    func openProject(_ p: M5Project) {
        NSWorkspace.shared.open(URL(fileURLWithPath: m5base+"/"+p.path))
    }

    func sendToBear(template: String = "") {
        let t = template.isEmpty ? bearNote : template
        guard !t.isEmpty else { return }
        let e = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        NSWorkspace.shared.open(URL(string: "bear://x-callback-url/create?text=\(e)")!)
        if template.isEmpty { bearNote = "" }
    }

    func statPill(_ label: String, _ value: Double, _ color: Color, _ detail: String = "") -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 7, weight: .bold)).foregroundColor(.gray)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08)).frame(height: 3)
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: max(CGFloat(value/100)*40, 2), height: 3)
            }
            Text(String(format: "%.0f%%", value)).font(.system(size: 8, design: .monospaced)).foregroundColor(color)
            if !detail.isEmpty { Text(detail).font(.system(size: 6)).foregroundColor(.white.opacity(0.3)).lineLimit(1) }
        }.frame(maxWidth: .infinity)
    }
}
