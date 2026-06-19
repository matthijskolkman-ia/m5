import SwiftUI

struct ContentView: View {
    @StateObject private var repairScene = RepairScene()
    @State private var isRunningDiagnostic = false
    @State private var diagnosticResult: String?

    private var selectedComponent: Component? {
        guard let id = repairScene.selectedComponent else { return nil }
        return Component.all.first { $0.id == id }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // ── Left: Component List (25%) ──
                ComponentSidebar(
                    selectedID: repairScene.selectedComponent,
                    onSelect: { id in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            repairScene.selectedComponent = id
                        }
                        repairScene.highlightComponent(named: id)
                    }
                )
                .frame(width: geo.size.width * 0.25)
                .background(Color(red: 0.06, green: 0.06, blue: 0.10))

                Divider().background(Color.white.opacity(0.08))

                // ── Center: 3D Scene (50%) ──
                ZStack(alignment: .topLeading) {
                    SceneKitView(scene: repairScene)

                    HStack {
                        Label("Vision Repair", systemImage: "apple.logo")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("Repair Bench — Seat 4")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
                .frame(width: geo.size.width * 0.50)

                Divider().background(Color.white.opacity(0.08))

                // ── Right: Diagnostics (25%) ──
                if let comp = selectedComponent {
                    ComponentDetailPanel(
                        component: comp,
                        isRunningDiagnostic: $isRunningDiagnostic,
                        diagnosticResult: $diagnosticResult,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                repairScene.selectedComponent = nil
                            }
                            repairScene.clearHighlight()
                            diagnosticResult = nil
                        }
                    )
                    .frame(width: geo.size.width * 0.25)
                } else {
                    EmptyStatePanel()
                        .frame(width: geo.size.width * 0.25)
                }
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Left Sidebar (25%)

struct ComponentSidebar: View {
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.caption).foregroundColor(.white.opacity(0.5))
                Text("COMPONENTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Text("\(Component.all.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Component.all) { comp in
                        Button {
                            onSelect(comp.id)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: comp.status.color))
                                    .frame(width: 6, height: 6)

                                Image(systemName: comp.icon)
                                    .font(.body)
                                    .foregroundColor(
                                        selectedID == comp.id
                                            ? .white
                                            : Color(hex: comp.status.color).opacity(0.7)
                                    )
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(comp.name)
                                        .font(.system(size: 12, weight: selectedID == comp.id ? .semibold : .regular))
                                        .foregroundColor(selectedID == comp.id ? .white : .white.opacity(0.7))
                                    Text(comp.partNumber)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.25))
                                }

                                Spacer()

                                Text(comp.status.rawValue)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Color(hex: comp.status.color))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(hex: comp.status.color).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(selectedID == comp.id ? Color.white.opacity(0.06) : Color.clear)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 52)
                            .background(Color.white.opacity(0.04))
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            Text("Apple Internal · Engineering Sample VP-0042")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))
                .padding(.bottom, 10)
        }
    }
}

// MARK: - Right Empty State (25%)

struct EmptyStatePanel: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "apple.logo")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.08))
            Text("Select a Component")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
            Text("Click a part on the headset\nor choose from the sidebar.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.15))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

// MARK: - Right Detail Panel (25%)

struct ComponentDetailPanel: View {
    let component: Component
    @Binding var isRunningDiagnostic: Bool
    @Binding var diagnosticResult: String?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(Color(hex: component.status.color))
                    .frame(width: 8, height: 8)
                Text("DIAGNOSTICS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: component.icon)
                            .font(.title)
                            .foregroundColor(Color(hex: component.status.color))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(component.name).font(.headline).foregroundColor(.white)
                            Text(component.status.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: component.status.color))
                        }
                    }

                    HStack(spacing: 6) {
                        Text("PART")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.25))
                        Text(component.partNumber)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Divider().background(Color.white.opacity(0.08))

                    Text(component.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineSpacing(5)

                    Divider().background(Color.white.opacity(0.08))

                    if let result = diagnosticResult {
                        // Diagnostic result
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Diagnostic Complete")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(result)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineSpacing(4)
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))

                        Divider().background(Color.white.opacity(0.08))
                    }

                    VStack(spacing: 6) {
                        Button {
                            runDiagnostic()
                        } label: {
                            HStack {
                                if isRunningDiagnostic {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                }
                                Text(isRunningDiagnostic ? "Running..." : "Run Diagnostic")
                                    .font(.system(size: 11))
                                Spacer()
                            }
                            .foregroundColor(isRunningDiagnostic ? .secondary : .blue)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.blue.opacity(isRunningDiagnostic ? 0.03 : 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(isRunningDiagnostic)

                        DetailButton("View Logs", "doc.text.fill", Color(white: 0.5))
                        DetailButton("Order Replacement", "shippingbox.fill", .orange)
                    }
                }
                .padding(16)
            }
        }
    }

    private func runDiagnostic() {
        isRunningDiagnostic = true
        diagnosticResult = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isRunningDiagnostic = false

            let results: [String: String] = [
                "display":   "OLED panel integrity: 100%. Dead pixels: 0. Color uniformity: Excellent. Brightness: 98% of spec. All good.",
                "sensors":   "12 cameras passed. LiDAR depth accuracy: ±1.2mm. IMU drift: 0.03°/hr. TrueDepth: nominal. Microphone array: all 6 clear.",
                "audio":     "Left pod: flat response ±0.8dB. Right pod: -2.1dB dip at 3.2kHz. Spatial audio mapping: recomputed. Recalibration advised.",
                "thermal":   "Fan 1: 1840 RPM. Fan 2: 1812 RPM. Peak temp under load: 41°C. Thermal paste integrity: good. No throttling detected.",
                "battery":   "Capacity: 87% of design (31.2Wh / 35.9Wh). Cycle count: 142. Cell balance: ±12mV. Replacement recommended within 180 days.",
                "lightseal": "Magnetic retention force: 8.2N (spec: 7–10N). Foam compression set: <5%. UV sanitization: complete. No light leakage detected.",
            ]

            diagnosticResult = results[component.id] ?? "All tests passed. Component operating within specifications."
        }
    }
}

struct DetailButton: View {
    let label: String; let icon: String; let color: Color
    init(_ label: String, _ icon: String, _ color: Color) {
        self.label = label; self.icon = icon; self.color = color
    }
    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.system(size: 11))
            Spacer()
        }
        .foregroundColor(color)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Hex Color

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
