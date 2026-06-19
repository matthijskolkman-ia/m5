import SwiftUI
import RealityKit

// MARK: - Planet Data

struct PlanetInfo: Identifiable {
    let id: String
    let name: String
    let baseColor: UIColor
    let bandColor: UIColor
    let size: Float
    let orbit: Float
    let speed: Float
    let hasRings: Bool
    let fact: String

    static let all: [PlanetInfo] = [
        PlanetInfo(id: "mercury", name: "Mercury", baseColor: .darkGray, bandColor: .lightGray,
                   size: 0.04, orbit: 0.20, speed: 4.0, hasRings: false,
                   fact: "Smallest planet. A year here is just 88 days!"),
        PlanetInfo(id: "venus", name: "Venus", baseColor: .orange, bandColor: .yellow,
                   size: 0.06, orbit: 0.30, speed: 3.0, hasRings: false,
                   fact: "Hottest planet — 465°C! Spins backwards too."),
        PlanetInfo(id: "earth", name: "Earth", baseColor: .systemBlue, bandColor: .green,
                   size: 0.07, orbit: 0.42, speed: 2.5, hasRings: false,
                   fact: "Your home! Only planet known to have pizza."),
        PlanetInfo(id: "mars", name: "Mars", baseColor: .systemRed, bandColor: .brown,
                   size: 0.05, orbit: 0.55, speed: 2.0, hasRings: false,
                   fact: "The Red Planet. Has the biggest volcano in the solar system."),
        PlanetInfo(id: "jupiter", name: "Jupiter", baseColor: .brown, bandColor: .systemOrange,
                   size: 0.16, orbit: 0.75, speed: 1.2, hasRings: false,
                   fact: "Biggest planet — over 1,300 Earths could fit inside!"),
        PlanetInfo(id: "saturn", name: "Saturn", baseColor: .systemYellow, bandColor: .systemOrange,
                   size: 0.13, orbit: 0.95, speed: 0.9, hasRings: true,
                   fact: "Those beautiful rings are made of ice and rock."),
        PlanetInfo(id: "uranus", name: "Uranus", baseColor: .systemCyan, bandColor: .systemTeal,
                   size: 0.10, orbit: 1.15, speed: 0.7, hasRings: false,
                   fact: "Rolls around the Sun on its side like a barrel!"),
        PlanetInfo(id: "neptune", name: "Neptune", baseColor: .systemPurple, bandColor: .systemBlue,
                   size: 0.09, orbit: 1.32, speed: 0.5, hasRings: false,
                   fact: "Windiest planet — storms blow at 2,100 km/h!"),
    ]
}

// MARK: - Procedural Texture Generator

func makePlanetTexture(base: UIColor, band: UIColor, size: Int = 256) -> TextureResource? {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    let image = renderer.image { ctx in
        let cg = ctx.cgContext

        // Base fill
        cg.setFillColor(base.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: size, height: size))

        // Horizontal bands
        let bandCount = Int.random(in: 3...7)
        for i in 0..<bandCount {
            let y = CGFloat(i) * CGFloat(size) / CGFloat(bandCount)
            let bandH = CGFloat(size) / CGFloat(bandCount) * 0.5
            let alpha = CGFloat.random(in: 0.15...0.6)
            cg.setFillColor(band.withAlphaComponent(alpha).cgColor)
            cg.fill(CGRect(x: 0, y: y + bandH * 0.25, width: CGFloat(size), height: bandH))
        }

        // Random spots / storms
        for _ in 0..<12 {
            let x = CGFloat.random(in: 0...CGFloat(size))
            let y = CGFloat.random(in: 0...CGFloat(size))
            let r = CGFloat.random(in: 4...CGFloat(size) / 8)
            cg.setFillColor(UIColor.white.withAlphaComponent(CGFloat.random(in: 0.05...0.15)).cgColor)
            cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }

        // Darker spots
        for _ in 0..<8 {
            let x = CGFloat.random(in: 0...CGFloat(size))
            let y = CGFloat.random(in: 0...CGFloat(size))
            let r = CGFloat.random(in: 3...CGFloat(size) / 10)
            cg.setFillColor(UIColor.black.withAlphaComponent(CGFloat.random(in: 0.05...0.2)).cgColor)
            cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
    }

    return try? TextureResource.generate(from: image.cgImage!, options: .init(semantic: .color))
}

// MARK: - Solar System Builder

@MainActor
final class SolarSystem {
    let root = Entity()
    private var planets: [(Entity, PlanetInfo)] = []

    func build() {
        buildSun()
        buildPlanets()
        startOrbits()
    }

    private func buildSun() {
        // Procedural fiery sun texture
        let sunTex = makeSunTexture()
        var sunMat = PhysicallyBasedMaterial()
        if let tex = sunTex {
            sunMat.baseColor = .init(texture: .init(tex))
        }
        sunMat.emissiveColor = .init(color: .systemYellow)
        sunMat.emissiveIntensity = 2.0

        let sun = ModelEntity(
            mesh: .generateSphere(radius: 0.12),
            materials: [sunMat]
        )
        sun.name = "sun"
        sun.position = [0, 0, 0]
        sun.collision = CollisionComponent(shapes: [.generateSphere(radius: 0.12)])
        sun.components.set(InputTargetComponent())

        // Glow
        let glow = ModelEntity(
            mesh: .generateSphere(radius: 0.18),
            materials: [SimpleMaterial(color: .systemYellow.withAlphaComponent(0.12), isMetallic: false)]
        )
        sun.addChild(glow)

        root.addChild(sun)
    }

    private func makeSunTexture() -> TextureResource? {
        let size = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.systemYellow.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: size, height: size))

            for _ in 0..<30 {
                let x = CGFloat.random(in: 0...CGFloat(size))
                let y = CGFloat.random(in: 0...CGFloat(size))
                let r = CGFloat.random(in: 8...40)
                let alpha = CGFloat.random(in: 0.1...0.4)
                cg.setFillColor(UIColor.orange.withAlphaComponent(alpha).cgColor)
                cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
        }
        return try? TextureResource.generate(from: image.cgImage!, options: .init(semantic: .color))
    }

    private func buildPlanets() {
        for info in PlanetInfo.all {
            let texture = makePlanetTexture(base: info.baseColor, band: info.bandColor)

            var mat = PhysicallyBasedMaterial()
            if let tex = texture {
                mat.baseColor = .init(texture: .init(tex))
            }
            mat.roughness = 0.9

            let planet = ModelEntity(
                mesh: .generateSphere(radius: info.size),
                materials: [mat]
            )
            planet.name = info.id

            // Collision for tap detection
            planet.collision = CollisionComponent(shapes: [.generateSphere(radius: info.size)])
            planet.components.set(InputTargetComponent())

            // Saturn's rings
            if info.hasRings {
                let ring = ModelEntity(
                    mesh: .generatePlane(width: info.size * 3.5, depth: info.size * 3.5, cornerRadius: info.size * 0.8),
                    materials: [SimpleMaterial(color: info.bandColor.withAlphaComponent(0.4), isMetallic: false)]
                )
                // Make it a ring by using a custom approach: large plane rotated
                ring.orientation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
                ring.orientation *= simd_quatf(angle: 0.3, axis: [1, 0, 0])
                planet.addChild(ring)
            }

            // Orbit pivot
            let pivot = Entity()
            pivot.position = [0, 0, 0]
            pivot.addChild(planet)
            planet.position = [info.orbit, 0, 0]

            root.addChild(pivot)
            planets.append((pivot, info))
        }
    }

    private func startOrbits() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for (pivot, info) in self.planets {
                    let angle = Float(Date().timeIntervalSinceReferenceDate) * info.speed * 0.5
                    pivot.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
                }
            }
        }
    }

    func handleTap(target: Entity?) -> PlanetInfo? {
        var node: Entity? = target
        while node != nil {
            if node?.name == "sun" {
                return PlanetInfo(
                    id: "sun", name: "The Sun", baseColor: .systemYellow, bandColor: .orange,
                    size: 0.12, orbit: 0, speed: 0, hasRings: false,
                    fact: "A star! 4.6 billion years old. Surface temp: 5,500°C. Core: 15 million °C!"
                )
            }
            if let name = node?.name, let planet = PlanetInfo.all.first(where: { $0.id == name }) {
                return planet
            }
            node = node?.parent
        }
        return nil
    }
}

// MARK: - App

@main
struct SolarSystemApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            SolarSystemView()
        }
        .defaultSize(width: 1.2, height: 0.9, depth: 0.9, in: .meters)
    }
}

struct SolarSystemView: View {
    @State private var system = SolarSystem()
    @State private var selectedPlanet: PlanetInfo?

    var body: some View {
        RealityView { content in
            system.build()
            content.add(system.root)
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    selectedPlanet = system.handleTap(target: value.entity)
                }
        )
        .ornament(attachmentAnchor: .scene(.bottom)) {
            if let planet = selectedPlanet {
                PlanetCard(planet: planet) { selectedPlanet = nil }
                    .frame(width: 300)
            } else {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Tap a planet!")
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .glassBackgroundEffect()
            }
        }
    }
}

struct PlanetCard: View {
    let planet: PlanetInfo
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(Color(planet.baseColor)).frame(width: 20, height: 20)
                Text(planet.name).font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            Text(planet.fact).font(.body).foregroundStyle(.secondary).lineSpacing(4)
        }
        .padding(16)
        .glassBackgroundEffect()
    }
}
