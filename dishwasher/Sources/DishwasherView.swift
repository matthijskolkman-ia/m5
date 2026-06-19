import SwiftUI

enum WashProgram: String, CaseIterable, Identifiable {
    case eco = "Eco", auto = "Auto", hot = "HOT", short = "Short", small = "Small"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .eco: "leaf.fill"; case .auto: "sensor.fill"; case .hot: "flame.fill"
        case .short: "bolt.fill"; case .small: "circle.grid.3x3.fill"
        }
    }
    var duration: TimeInterval {
        switch self {
        case .eco: 150; case .auto: 120; case .hot: 100; case .short: 45; case .small: 60
        }
    }
    var temp: Int {
        switch self {
        case .eco: 45; case .auto: 55; case .hot: 70; case .short: 40; case .small: 35
        }
    }
    var color: Color {
        switch self {
        case .eco: .green; case .auto: .blue; case .hot: .red; case .short: .yellow; case .small: .teal
        }
    }
}

enum WashPhase: String {
    case idle = "Ready", prewash = "Pre-wash", washing = "Washing"
    case rinsing = "Rinsing", drying = "Drying", done = "Done"
}

struct DishwasherView: View {
    @State private var program: WashProgram = .auto
    @State private var phase: WashPhase = .idle
    @State private var timeRemaining: TimeInterval = 0
    @State private var isRunning = false
    @State private var waterLevel: CGFloat = 0
    @State private var bubbleOpacity: CGFloat = 0
    @State private var dishesOpacity: CGFloat = 0.3
    @State private var steamOpacity: CGFloat = 0

    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Program row
            HStack(spacing: 3) {
                ForEach(WashProgram.allCases) { p in
                    Button { if !isRunning { program = p } } label: {
                        VStack(spacing: 1) {
                            Image(systemName: p.icon).font(.system(size: 9))
                            Text(p.rawValue).font(.system(size: 7, weight: .medium))
                        }
                        .foregroundColor(program == p ? p.color : .white.opacity(0.3))
                        .frame(maxWidth: .infinity).padding(.vertical, 3)
                        .background(program == p ? p.color.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 4).padding(.top, 4)

            // Dishwasher visual
            compactBody.padding(.horizontal, 6).padding(.vertical, 3)

            // Bottom bar
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(phase.rawValue).font(.system(size: 8, weight: .medium))
                        .foregroundColor(phase == .done ? .green : program.color)
                    Text("\(program.temp)°C").font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.25))
                }
                Spacer()
                if isRunning || phase == .done {
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(phase == .done ? .green : program.color)
                }
                Spacer()
                Button(action: toggleCycle) {
                    Image(systemName: isRunning ? "pause.fill" : (phase == .done ? "arrow.counterclockwise" : "play.fill"))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(isRunning ? Color.orange : program.color).clipShape(Circle())
                }.buttonStyle(.plain)
            }.padding(.horizontal, 6).padding(.bottom, 4)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            guard isRunning else { return }
            if timeRemaining > 0 { timeRemaining -= 0.05; updateAnimations() }
            else { completeCycle() }
        }
        .onChange(of: program) { _, _ in if !isRunning && phase != .done { timeRemaining = program.duration } }
        .onAppear { timeRemaining = program.duration }
    }

    var compactBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
            RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.04, green: 0.04, blue: 0.08)).padding(4)

            // Water
            VStack { Spacer()
                Rectangle().fill(LinearGradient(colors: [.clear, program.color.opacity(0.15), program.color.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 30 * waterLevel).opacity(waterLevel > 0 ? 1 : 0)
            }.padding(.horizontal, 6).padding(.bottom, 6)

            // Status indicator light
            HStack {
                Spacer()
                VStack {
                    Circle()
                        .fill(isRunning ? program.color : Color.white.opacity(0.08))
                        .frame(width: 4, height: 4)
                        .shadow(color: isRunning ? program.color : .clear, radius: 3)
                    Spacer()
                }
                .padding(.top, 5).padding(.trailing, 5)
            }

            // Dishes
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill").font(.system(size: 10))
                    Image(systemName: "wineglass.fill").font(.system(size: 11))
                    Spacer()
                    Image(systemName: "mug.fill").font(.system(size: 10))
                }
                HStack(spacing: 5) {
                    Image(systemName: "fork.knife").font(.system(size: 11))
                    Image(systemName: "circle.fill").font(.system(size: 15))
                    Image(systemName: "rectangle.fill").font(.system(size: 14))
                    Spacer()
                    Image(systemName: "bowl.fill").font(.system(size: 12))
                }
            }
            .foregroundColor(.white.opacity(0.3))
            .opacity(dishesOpacity).padding(.horizontal, 14)

            // Bubbles
            if bubbleOpacity > 0 {
                ForEach(0..<8, id: \.self) { i in
                    Circle().fill(.white.opacity(0.1 * bubbleOpacity))
                        .frame(width: CGFloat.random(in: 3...8))
                        .offset(x: CGFloat.random(in: -25...25), y: CGFloat.random(in: -15...10))
                }
            }

            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.02)).padding(4)
        }.frame(height: 66)
    }

    func updateAnimations() {
        let p = 1 - (timeRemaining / program.duration)
        switch p {
        case 0..<0.1: phase = .prewash; waterLevel = p*8; bubbleOpacity = p*2; dishesOpacity = 0.3+p*3; steamOpacity = 0
        case 0.1..<0.5: phase = .washing; waterLevel = 0.8; bubbleOpacity = min(1,(p-0.1)*3); dishesOpacity = 0.6; steamOpacity = 0
        case 0.5..<0.7: phase = .rinsing; waterLevel = 0.6; bubbleOpacity = max(0,1-(p-0.5)*5); dishesOpacity = 0.7; steamOpacity = 0
        case 0.7..<0.9: phase = .drying; waterLevel = max(0,0.6-(p-0.7)*6); bubbleOpacity = 0; dishesOpacity = 0.7; steamOpacity = (p-0.7)*3
        default: phase = .drying; waterLevel = 0; bubbleOpacity = 0; dishesOpacity = 0.7; steamOpacity = max(0,1-(p-0.9)*10)
        }
    }

    func toggleCycle() {
        if phase == .done { reset(); return }
        isRunning.toggle()
    }

    func completeCycle() { isRunning = false; phase = .done; timeRemaining = 0; waterLevel = 0; bubbleOpacity = 0; steamOpacity = 0; dishesOpacity = 0.8 }

    func reset() { phase = .idle; timeRemaining = program.duration; waterLevel = 0; bubbleOpacity = 0; steamOpacity = 0; dishesOpacity = 0.3 }

    func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t)/60; let s = Int(t)%60
        return String(format: "%d:%02d", m, s)
    }
}
