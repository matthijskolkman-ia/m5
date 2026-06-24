import SwiftUI
import AppKit

// MARK: - App

@main
struct WashingMachineApp: App {
    var body: some Scene {
        WindowGroup {
            WashView()
                .frame(minWidth: 240, maxWidth: 240, minHeight: 290, maxHeight: 290)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 240, height: 290)
    }
}

// MARK: - Programs

enum WProgram: String, CaseIterable, Identifiable {
    case quick = "Quick", normal = "Normal", heavy = "Heavy"
    var id: String { rawValue }
    var icon: String {
        switch self { case .quick: "bolt.fill"; case .normal: "tshirt.fill"; case .heavy: "jacket.fill" }
    }
    var color: Color {
        switch self { case .quick: .green; case .normal: .blue; case .heavy: .orange }
    }
}

// MARK: - View

struct WashView: View {
    @State private var program: WProgram = .normal
    @State private var isRunning = false
    @State private var spinAngle: CGFloat = 0
    @State private var waterLevel: CGFloat = 0
    @State private var bubbleOpacity: CGFloat = 0
    @State private var foamOffset: CGFloat = 0
    @State private var logs: [String] = []
    @State private var task: Process?

    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("🧺 Washing Machine").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Circle().fill(isRunning ? program.color : Color.white.opacity(0.1))
                    .frame(width: 5, height: 5)
                    .shadow(color: isRunning ? program.color : .clear, radius: 4)
            }.padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

            // Programs
            HStack(spacing: 3) {
                ForEach(WProgram.allCases) { p in
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

                // Clothes inside drum
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * 60 + spinAngle * 2
                    Image(systemName: ["tshirt.fill","sock.fill","jeans"][i%3])
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.2))
                        .offset(x: cos(angle * .pi / 180) * 24, y: sin(angle * .pi / 180) * 24)
                        .rotationEffect(.degrees(spinAngle))
                }

                // Water
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, program.color.opacity(0.1), program.color.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                    .opacity(waterLevel).padding(.horizontal, 12).padding(.bottom, 8)

                // Bubbles
                if bubbleOpacity > 0 {
                    ForEach(0..<10, id: \.self) { i in
                        Circle()
                            .fill(.white.opacity(0.08 * bubbleOpacity))
                            .frame(width: CGFloat.random(in: 3..<7))
                            .offset(x: CGFloat.random(in: -35...35) + foamOffset, y: CGFloat.random(in: -10...20) + foamOffset * 0.5)
                    }
                }

                // Glass door reflection
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
                Text(isRunning ? "Watching inbox..." : "Ready")
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
                spinAngle += 1.5
                waterLevel = 0.5 + sin(Date().timeIntervalSince1970 * 0.5) * 0.2
                bubbleOpacity = 0.3 + sin(Date().timeIntervalSince1970 * 1.3) * 0.3
                foamOffset = sin(Date().timeIntervalSince1970 * 0.7) * 5
            }
        }
    }

    func toggle() {
        isRunning.toggle()
        if isRunning {
            logs.append("🧺 Watching \(program.rawValue)...")
            startScript()
        } else {
            task?.terminate()
            task = nil
            logs.append("⏹️ Stopped")
            waterLevel = 0; bubbleOpacity = 0
        }
    }

    func startScript() {
        let scriptPath = NSHomeDirectory() + "/Documents/m5/washing-machine/wash.py"
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
