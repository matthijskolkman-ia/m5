import Foundation

/// Repairable components of the Vision Pro
struct Component: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let partNumber: String
    let status: ComponentStatus
    let description: String

    static let all: [Component] = [
        Component(
            id: "display",
            name: "Micro-OLED Displays",
            icon: "eye.fill",
            partNumber: "661-12345",
            status: .nominal,
            description: "Dual 4K micro-OLED panels. 23 million pixels per eye. Refresh rate locked at 90/96/100Hz. Pixel density: 3,386 PPI."
        ),
        Component(
            id: "sensors",
            name: "Sensor Array",
            icon: "dot.radiowaves.left.and.right",
            partNumber: "661-12346",
            status: .nominal,
            description: "12 cameras, 5 sensors, 6 microphones. LiDAR scanner operational. TrueDepth camera calibrated. Downward-facing cameras clean."
        ),
        Component(
            id: "audio",
            name: "Audio Pods",
            icon: "hifispeaker.fill",
            partNumber: "661-12347",
            status: .attention,
            description: "Dual-driver spatial audio. Left pod: nominal. Right pod: slight imbalance at 2kHz–4kHz range. Recommend recalibration."
        ),
        Component(
            id: "thermal",
            name: "Thermal System",
            icon: "thermometer.medium",
            partNumber: "661-12348",
            status: .nominal,
            description: "Dual fan assembly. Operational range: 0°C–35°C. Current idle temp: 34°C. Fan curve: auto (silent under 38°C)."
        ),
        Component(
            id: "battery",
            name: "External Battery",
            icon: "battery.75percent",
            partNumber: "661-12349",
            status: .warning,
            description: "35.9Wh lithium polymer. Cycle count: 142 of 500. Health: 87%. Estimated runtime: 1h 52m. Recommend replacement within 6 months."
        ),
        Component(
            id: "lightseal",
            name: "Light Seal",
            icon: "circle.dotted",
            partNumber: "661-12350",
            status: .nominal,
            description: "Size 21W magnetic light seal. Foam integrity: excellent. No light bleed detected. Cleaned and sanitized."
        ),
    ]
}

enum ComponentStatus: String, Equatable {
    case nominal = "Nominal"
    case attention = "Attention"
    case warning = "Warning"
    case failed = "Failed"

    var color: String {
        switch self {
        case .nominal:   return "#22c55e"
        case .attention: return "#f59e0b"
        case .warning:   return "#f97316"
        case .failed:    return "#ef4444"
        }
    }

    var symbol: String {
        switch self {
        case .nominal:   return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .warning:   return "exclamationmark.triangle.fill"
        case .failed:    return "xmark.octagon.fill"
        }
    }
}
