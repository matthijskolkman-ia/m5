import SwiftUI

// MARK: - App

@main
struct DryerApp: App {
    var body: some Scene {
        WindowGroup {
            DryerView()
                .frame(minWidth: 240, maxWidth: 240, minHeight: 290, maxHeight: 290)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 240, height: 290)
    }
}

// MARK: - Programs

enum DProgram: String, CaseIterable, Identifiable {
    case quick = "Quick", normal = "Normal", delicate = "Delicate"
    var id: String { rawValue }
    var icon: String {
        switch self { case .quick: "bolt.fill"; case .normal: "tshirt.fill"; case .delicate: "leaf.fill" }
    }
    var color: Color {
        switch self { case .quick: .orange; case .normal: .red; case .delicate: .pink }
    }
}

// MARK: - View

struct DryerView: View {
    @State private var program: DProgram = .normal
    @State private var isRunning = false
    @State private var spinAngle: CGFloat = 0
    @State private var heatGlow: CGFloat = 0
    @State private var lintOpacity: CGFloat = 0
    @State private var logs: [String] = []
    @State private var task: Process?

    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("🌀 Dryer").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Circle().fill(isRunning ? program.color : Color.white.opacity(0.1))
                    .frame(width: 5, height: 5)
                    .shadow(color: isRunning ? program.color : .clear, radius: 4)
            }.padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

            // Programs
            HStack(spacing: 3) {
                ForEach(DProgram.allCases) { p in
                    Button { if !isRunning { program = p } } label: {
                        VStack(spacing: 1) {
                            Image(systemName: p.icon).font(.system(size: 9))
                            Text(p.rawValue).font(.system(size: 7, weight: .medium))
                        }
                        .foregroundColor(program == p ? p.color : .white.opacity(0.3))
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                        .background(program == p ? p.color.opacity(0.12) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 6)

            // Drum
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06)))
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.04, green: 0.04, blue: 0.08)).padding(3)

                // Drum circle
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(spinAngle))

                // Heat glow
                Circle()
                    .fill(program.color.opacity(0.03 * heatGlow))
                    .frame(width: 80, height: 80)
                    .blur(radius: 8)

                // Clothes tumbling
                ForEach(0..<5, id: \.self) { i in
                    let angle = Double(i) * 72 + spinAngle
                    Image(systemName: ["tshirt.fill","sock.fill","jeans","towel.fill"][i%4])
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.25))
                        .offset(x: cos(angle * .pi / 180) * 20, y: sin(angle * .pi / 180) * 20 + sin(spinAngle * 0.05) * 8)
                        .rotationEffect(.degrees(spinAngle * 0.5))
                }

                // Lint
                if lintOpacity > 0 {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(program.color.opacity(0.05 * lintOpacity))
                            .frame(width: 3, height: 3)
                            .offset(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: -25...25))
                    }
                }

                // Glass door
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.02)).padding(3)
            }.frame(height: 120).padding(.horizontal, 8).padding(.vertical, 4)

            // Logs
            if !logs.isEmpty {
                ScrollViewReader { sv in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(logs.suffix(4), id: \.self) { log in
                                Text(log).font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3)).id(log)
                            }
                        }.padding(.horizontal, 8)
                    }.frame(height: 36)
                    .onChange(of: logs) { _, _ in if let last = logs.last { sv.scrollTo(last) } }
                }
            }

            // Controls
            HStack {
                Text(isRunning ? "Drying..." : "Ready")
                    .font(.system(size: 8, weight: .medium)).foregroundColor(isRunning ? program.color : .white.opacity(0.25))
                Spacer()
                Button(action: toggle) {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(isRunning ? Color.red : program.color).clipShape(Circle())
                }.buttonStyle(.plain)
            }.padding(.horizontal, 10).padding(.bottom, 8)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            if isRunning {
                spinAngle += 2.0
                heatGlow = 0.5 + sin(Date().timeIntervalSince1970 * 0.8) * 0.5
                lintOpacity = 0.2 + sin(Date().timeIntervalSince1970 * 1.1) * 0.3
            }
        }
    }

    func toggle() {
        isRunning.toggle()
        if isRunning {
            logs.append("🌀 Drying (\(program.rawValue))...")
            startScript()
        } else {
            task?.terminate()
            task = nil
            logs.append("⏹️ Stopped")
            heatGlow = 0; lintOpacity = 0
        }
    }

    func startScript() {
        let scriptPath = NSHomeDirectory() + "/Documents/m5/dryer/dry.py"
        let p = Process()
        p.launchPath = "/usr/bin/python3"
        p.arguments = [scriptPath]

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { h in
            if let line = String(data: h.availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                DispatchQueue.main.async { logs.append(line) }
            }
        }
        try? p.run()
        task = p
        logs.append("▶️ Started")
    }
}
