import SceneKit
import SwiftUI

/// Builds the 3D repair bench scene with Vision Pro model
final class RepairScene: SCNScene, ObservableObject {
    @Published var selectedComponent: String?

    private let headsetNode = SCNNode()
    private var highlightNode: SCNNode?

    override init() {
        super.init()
        buildEnvironment()
        buildBench()
        buildVisionPro()
        buildLighting()
        startRotation()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Environment

    private func buildEnvironment() {
        background.contents = CGColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
        fogColor = NSColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1)
        fogStartDistance = 2
        fogEndDistance = 8

        // Camera
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 20
        camera.fieldOfView = 50
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.3, 2.5)
        cameraNode.look(at: SCNVector3(0, 0.05, 0))
        rootNode.addChildNode(cameraNode)
    }

    // MARK: - Bench

    private func buildBench() {
        // Workbench surface
        let benchGeom = SCNBox(width: 3.0, height: 0.06, length: 2.0, chamferRadius: 0.02)
        let benchMat = SCNMaterial()
        benchMat.diffuse.contents = NSColor(white: 0.12, alpha: 1)
        benchMat.metalness.contents = 0.9
        benchMat.roughness.contents = 0.3
        benchMat.specular.contents = NSColor(white: 0.6, alpha: 1)
        benchGeom.materials = [benchMat]

        let benchNode = SCNNode(geometry: benchGeom)
        benchNode.position = SCNVector3(0, -0.45, 0)
        benchNode.name = "bench"
        rootNode.addChildNode(benchNode)

        // Reflection on the bench
        let floor = SCNFloor()
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = NSColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1)
        floorMat.metalness.contents = 0.5
        floorMat.roughness.contents = 0.2
        floor.materials = [floorMat]
        floor.reflectivity = 0.3

        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.48, 0)
        rootNode.addChildNode(floorNode)

        // Subtle grid lines on bench (decorative)
        addGridLines()
    }

    private func addGridLines() {
        for i in -3...3 {
            let lineGeom = SCNCylinder(radius: 0.001, height: 3.0)
            let lineMat = SCNMaterial()
            lineMat.diffuse.contents = NSColor(white: 0.25, alpha: 0.3)
            lineGeom.materials = [lineMat]

            let lineNode = SCNNode(geometry: lineGeom)
            lineNode.position = SCNVector3(Float(i) * 0.5, -0.42, 0)
            lineNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            rootNode.addChildNode(lineNode)
        }
    }

    // MARK: - Vision Pro Model

    private func buildVisionPro() {
        // ── Glass Front (curved visor) ──
        let glassGeom = SCNBox(width: 0.52, height: 0.34, length: 0.12, chamferRadius: 0.04)
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents = NSColor(red: 0.15, green: 0.12, blue: 0.25, alpha: 0.85)
        glassMat.metalness.contents = 0.4
        glassMat.roughness.contents = 0.15
        glassMat.transparency = 0.7
        glassMat.specular.contents = NSColor(white: 0.9, alpha: 1)
        glassMat.emission.contents = NSColor(red: 0.05, green: 0.02, blue: 0.15, alpha: 1)
        glassGeom.materials = [glassMat]

        let glassNode = SCNNode(geometry: glassGeom)
        glassNode.name = "display"
        glassNode.position = SCNVector3(0, 0, 0.06)

        // Curve the glass slightly (bend outward)
        let glassPivot = SCNNode()
        glassPivot.addChildNode(glassNode)
        headsetNode.addChildNode(glassPivot)

        // ── Aluminum Frame (ring around the visor) ──
        let frameGeom = SCNBox(width: 0.56, height: 0.38, length: 0.14, chamferRadius: 0.05)
        let frameMat = SCNMaterial()
        frameMat.diffuse.contents = NSColor(white: 0.65, alpha: 1)
        frameMat.metalness.contents = 0.95
        frameMat.roughness.contents = 0.25
        frameMat.specular.contents = NSColor(white: 0.8, alpha: 1)
        frameGeom.materials = [frameMat]

        let frameNode = SCNNode(geometry: frameGeom)
        frameNode.name = "frame"
        headsetNode.addChildNode(frameNode)

        // ── Light Seal ──
        let sealGeom = SCNBox(width: 0.48, height: 0.30, length: 0.08, chamferRadius: 0.03)
        let sealMat = SCNMaterial()
        sealMat.diffuse.contents = NSColor(white: 0.18, alpha: 1)
        sealMat.metalness.contents = 0.1
        sealMat.roughness.contents = 0.9
        sealGeom.materials = [sealMat]

        let sealNode = SCNNode(geometry: sealGeom)
        sealNode.name = "lightseal"
        sealNode.position = SCNVector3(0, 0, -0.11)
        headsetNode.addChildNode(sealNode)

        // ── Sensor bump (top center) ──
        let sensorGeom = SCNBox(width: 0.16, height: 0.04, length: 0.06, chamferRadius: 0.01)
        sensorGeom.materials = [frameMat]
        let sensorNode = SCNNode(geometry: sensorGeom)
        sensorNode.name = "sensors"
        sensorNode.position = SCNVector3(0, 0.20, 0.04)
        headsetNode.addChildNode(sensorNode)

        // ── Side arms (audio pods) ──
        for side: Float in [-1, 1] {
            let armGeom = SCNCylinder(radius: 0.03, height: 0.08)
            armGeom.materials = [frameMat]
            let armNode = SCNNode(geometry: armGeom)
            armNode.name = "audio"
            armNode.position = SCNVector3(side * 0.30, 0, 0)
            armNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            headsetNode.addChildNode(armNode)

            // Headband connector
            let bandGeom = SCNCylinder(radius: 0.015, height: 0.5)
            let bandMat = SCNMaterial()
            bandMat.diffuse.contents = NSColor(white: 0.22, alpha: 1)
            bandMat.metalness.contents = 0.3
            bandMat.roughness.contents = 0.7
            bandGeom.materials = [bandMat]

            let bandNode = SCNNode(geometry: bandGeom)
            bandNode.position = SCNVector3(side * 0.28, 0.02, -0.28)
            bandNode.eulerAngles = SCNVector3(0.4, 0, Float.pi / 2 * side)
            headsetNode.addChildNode(bandNode)
        }

        // ── Headband (curved top) ──
        let bandCurveGeom = SCNTorus(ringRadius: 0.28, pipeRadius: 0.014)
        let bandCurveMat = SCNMaterial()
        bandCurveMat.diffuse.contents = NSColor(white: 0.25, alpha: 1)
        bandCurveMat.metalness.contents = 0.2
        bandCurveMat.roughness.contents = 0.8
        bandCurveGeom.materials = [bandCurveMat]

        let bandCurveNode = SCNNode(geometry: bandCurveGeom)
        bandCurveNode.position = SCNVector3(0, 0.1, -0.3)
        bandCurveNode.eulerAngles = SCNVector3(Float.pi / 2, 0, Float.pi / 2)
        headsetNode.addChildNode(bandCurveNode)

        // Position the whole headset on the bench
        headsetNode.position = SCNVector3(0, -0.15, 0)
        rootNode.addChildNode(headsetNode)
    }

    // MARK: - Lighting

    private func buildLighting() {
        // Key spotlight from above
        let keyLight = SCNLight()
        keyLight.type = .spot
        keyLight.color = NSColor(white: 0.95, alpha: 1)
        keyLight.intensity = 1200
        keyLight.spotInnerAngle = 30
        keyLight.spotOuterAngle = 60
        keyLight.castsShadow = true
        keyLight.shadowRadius = 3
        keyLight.shadowSampleCount = 32

        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(0, 1.5, 0.8)
        keyNode.look(at: SCNVector3(0, 0, 0))
        rootNode.addChildNode(keyNode)

        // Ambient fill
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.1, green: 0.08, blue: 0.18, alpha: 1)
        ambientLight.intensity = 200

        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        rootNode.addChildNode(ambientNode)

        // Rim light (from behind)
        let rimLight = SCNLight()
        rimLight.type = .omni
        rimLight.color = NSColor(red: 0.3, green: 0.2, blue: 0.5, alpha: 1)
        rimLight.intensity = 300

        let rimNode = SCNNode()
        rimNode.light = rimLight
        rimNode.position = SCNVector3(0, 0.1, -0.8)
        rootNode.addChildNode(rimNode)
    }

    // MARK: - Animation

    private func startRotation() {
        let rotate = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 60)
        )
        headsetNode.runAction(rotate)
    }

    // MARK: - Hit Testing

    func highlightComponent(named name: String) {
        guard let node = findNode(named: name, in: headsetNode) else { return }
        highlight(node: node)
    }

    func clearHighlight() {
        unhighlight()
        selectedComponent = nil
    }

    private func findNode(named name: String, in parent: SCNNode) -> SCNNode? {
        if parent.name == name { return parent }
        for child in parent.childNodes {
            if let found = findNode(named: name, in: child) {
                return found
            }
        }
        return nil
    }

    func handleClick(at point: CGPoint, in view: SCNView) {
        let hits = view.hitTest(point, options: [
            .categoryBitMask: 1,
            .searchMode: SCNHitTestSearchMode.all.rawValue,
        ])

        // Walk up from hit node to find a named component
        for hit in hits {
            var node: SCNNode? = hit.node
            while node != nil {
                if let name = node?.name, Component.all.contains(where: { $0.id == name }) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedComponent = name
                    }
                    highlight(node: node!)
                    return
                }
                node = node?.parent
            }
        }

        // Clicked empty space — deselect
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedComponent = nil
        }
        unhighlight()
    }

    private func highlight(node: SCNNode) {
        unhighlight()

        let glowGeom = node.geometry?.copy() as? SCNGeometry
        guard let geom = glowGeom else { return }

        let highlightMat = SCNMaterial()
        highlightMat.diffuse.contents = NSColor.clear
        highlightMat.emission.contents = NSColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 1)
        highlightMat.transparency = 0.3
        geom.materials = [highlightMat]

        let hNode = SCNNode(geometry: geom)
        hNode.name = "_highlight"
        hNode.scale = SCNVector3(1.08, 1.08, 1.08)
        node.addChildNode(hNode)

        highlightNode = hNode
    }

    private func unhighlight() {
        highlightNode?.removeFromParentNode()
        highlightNode = nil
    }
}

// MARK: - SwiftUI Representable

struct SceneKitView: NSViewRepresentable {
    let scene: RepairScene

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
        view.antialiasingMode = .multisampling4X

        // Click handler
        let click = NSClickGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.handleClick(_:)))
        view.addGestureRecognizer(click)

        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene)
    }

    class Coordinator: NSObject {
        let scene: RepairScene
        init(scene: RepairScene) { self.scene = scene }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            scene.handleClick(at: point, in: view)
        }
    }
}
