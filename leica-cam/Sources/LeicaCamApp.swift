import SwiftUI
import AVFoundation
import CoreImage

// MARK: - App

@main
struct LeicaCamApp: App {
    var body: some Scene {
        WindowGroup { CameraView() }
    }
}

// MARK: - Frame Lines

enum FrameLine: String, CaseIterable {
    case f35="35mm", f50="50mm", f90="90mm"
    var scale: CGFloat { switch self { case .f35: 1.0; case .f50: 0.85; case .f90: 0.65 } }
}

// MARK: - Engine

@MainActor
final class LeicaEngine: NSObject, ObservableObject {
    @Published var lensPosition: Float = 0.5
    @Published var isManualFocus = false
    @Published var frameLine: FrameLine = .f50
    @Published var exposureBias: Float = 0
    @Published var status = "Starting..."
    @Published var isCapturing = false
    @Published var zebraOn = false
    @Published var histOn = false
    @Published var histogram = [Int](repeating: 0, count: 256)
    @Published var intervalOn = false
    @Published var intervalN = 0

    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let videoOut = AVCaptureVideoDataOutput()
    private let photoOut = AVCapturePhotoOutput()
    private var cam: AVCaptureDevice?

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else { status = "Denied"; return }
        guard let c = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { status = "No camera"; return }
        cam = c
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let inp = try? AVCaptureDeviceInput(device: c), session.canAddInput(inp) { session.addInput(inp) }
        videoOut.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ml"))
        videoOut.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOut) { session.addOutput(videoOut) }
        if session.canAddOutput(photoOut) { session.addOutput(photoOut) }
        session.commitConfiguration()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        status = "Leica M · 50mm"
    }

    func selectFrameLine(_ fl: FrameLine) { frameLine = fl; status = "Leica M · \(fl.rawValue)" }
    func toggleZebra() { zebraOn.toggle() }
    func toggleHist() { histOn.toggle() }

    func evUp() { setEV(exposureBias + 0.3) }
    func evDown() { setEV(exposureBias - 0.3) }
    private func setEV(_ v: Float) {
        guard let c = cam else { return }
        let clamped = min(max(v, -3), 3)
        try? c.lockForConfiguration(); c.setExposureTargetBias(clamped); c.unlockForConfiguration()
        exposureBias = clamped
    }

    func toggleInterval() {
        intervalOn.toggle()
        if intervalOn { intervalN = 0; fireInterval() }
    }
    private func fireInterval() {
        guard intervalOn else { return }
        capture(); intervalN += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.fireInterval() }
    }

    func focusAt(pt: CGPoint, size: CGSize) {
        guard let c = cam else { return }
        try? c.lockForConfiguration()
        if c.isFocusPointOfInterestSupported { c.focusPointOfInterest = CGPoint(x: pt.x/size.width, y: pt.y/size.height); c.focusMode = .autoFocus }
        if c.isExposurePointOfInterestSupported { c.exposurePointOfInterest = CGPoint(x: pt.x/size.width, y: pt.y/size.height); c.exposureMode = .autoExpose }
        c.unlockForConfiguration()
        isManualFocus = false
    }

    func toggleFocusLock() {
        guard let c = cam else { return }
        isManualFocus.toggle()
        let pos: Float = isManualFocus ? 0.3 : 0.5
        try? c.lockForConfiguration(); c.setFocusModeLocked(lensPosition: pos); c.unlockForConfiguration()
    }

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        photoOut.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}

extension LeicaEngine: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ o: AVCapturePhotoOutput, didFinishProcessingPhoto p: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            isCapturing = false
            if let d = p.fileDataRepresentation(), let img = UIImage(data: d) {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil); status = "Saved"
            }
        }
    }
}

extension LeicaEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ o: AVCaptureOutput, didOutput buf: CMSampleBuffer, from conn: AVCaptureConnection) {
        guard let px = CMSampleBufferGetImageBuffer(buf) else { return }
        let ci = CIImage(cvPixelBuffer: px).transformed(by: CGAffineTransform(scaleX: 0.125, y: 0.125))
        var h = [Int](repeating: 0, count: 256)
        let ctx = CIContext()
        if let cg = ctx.createCGImage(ci, from: ci.extent) {
            let w = cg.width, bpr = w * 4
            var raw = [UInt8](repeating: 0, count: cg.height * bpr)
            let cs = CGColorSpaceCreateDeviceRGB()
            if let dc = CGContext(data: &raw, width: w, height: cg.height, bitsPerComponent: 8, bytesPerRow: bpr, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
                dc.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: cg.height))
                let step = max(1, raw.count / 8000)
                for i in stride(from: 0, to: raw.count - 4, by: step * 4) {
                    let lum = (Int(raw[i])*299 + Int(raw[i+1])*587 + Int(raw[i+2])*114)/1000
                    h[min(lum, 255)] &+= 1
                }
            }
        }
        Task { @MainActor in self.histogram = h }
    }
}

// MARK: - Preview

final class PV: UIView {
    var pl: AVCaptureVideoPreviewLayer? { didSet { oldValue?.removeFromSuperlayer(); if let l = pl { layer.insertSublayer(l, at: 0) } } }
    override func layoutSubviews() { super.layoutSubviews(); pl?.frame = bounds }
}

struct Preview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer
    func makeUIView(context: Context) -> PV { let v = PV(); v.pl = layer; return v }
    func updateUIView(_ v: PV, context: Context) {}
}

// MARK: - Overlays

struct FrameOverlay: View {
    let fl: FrameLine; let sz: CGSize
    var body: some View {
        let s = fl.scale; let w = sz.width * s; let h = w / 1.5
        ZStack {
            Rectangle().fill(.black.opacity(0.25)).ignoresSafeArea()
            RoundedRectangle(cornerRadius: 2).fill(.clear).frame(width: w, height: h)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.5), lineWidth: 1))
                .blendMode(.destinationOut)
        }.compositingGroup().allowsHitTesting(false)
    }
}

struct ZebraOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            for x in stride(from: 0, through: size.width, by: 10) {
                var p = Path()
                for y in stride(from: 0, through: size.height, by: 35) {
                    let ox = (x + y).truncatingRemainder(dividingBy: 20)
                    p.move(to: CGPoint(x: ox, y: y))
                    p.addLine(to: CGPoint(x: ox + 8, y: y))
                }
                ctx.stroke(p, with: .color(.orange.opacity(0.3)), lineWidth: 1)
            }
        }.allowsHitTesting(false)
    }
}

struct HistView: View {
    let data: [Int]
    var body: some View {
        Canvas { ctx, size in
            guard let mx = data.max(), mx > 0 else { return }
            let bw = size.width / 256
            for (i, v) in data.enumerated() where v > 0 {
                let h = (CGFloat(v)/CGFloat(mx)) * size.height
                ctx.fill(Path(CGRect(x: CGFloat(i)*bw, y: size.height-h, width: max(bw,1), height: h)), with: .color(.cyan.opacity(0.6)))
            }
        }.background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - UI

struct CameraView: View {
    @StateObject private var e = LeicaEngine()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                Preview(layer: e.previewLayer).ignoresSafeArea()
                FrameOverlay(fl: e.frameLine, sz: geo.size)
                if e.zebraOn { ZebraOverlay().ignoresSafeArea() }
                if e.histOn { HistView(data: e.histogram).frame(width: 100, height: 50).position(x: geo.size.width - 60, y: geo.size.height - 120) }

                VStack {
                    Text(e.status).font(.system(size: 12, design: .monospaced)).foregroundColor(.red)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.ultraThinMaterial).clipShape(Capsule()).padding(.top, 50)
                    Spacer()

                    // Frame lines
                    HStack(spacing: 8) {
                        ForEach(FrameLine.allCases, id: \.self) { fl in
                            Button { e.selectFrameLine(fl) } label: {
                                Text(fl.rawValue).font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(e.frameLine == fl ? .red : .secondary)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background((e.frameLine == fl ? Color.red : .white).opacity(e.frameLine == fl ? 0.15 : 0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }.padding(.bottom, 12)

                    // Bottom controls
                    HStack(alignment: .center) {
                        VStack(spacing: 18) {
                            Button { e.toggleZebra() } label: { Image(systemName: "rectangle.split.2x2").font(.title3).frame(width: 44, height: 44).foregroundColor(e.zebraOn ? .orange : .secondary) }
                            Button { e.toggleHist() } label: { Image(systemName: "chart.bar.fill").font(.title3).frame(width: 44, height: 44).foregroundColor(e.histOn ? .cyan : .secondary) }
                            Button { e.toggleInterval() } label: {
                                VStack(spacing: 0) { Image(systemName: "timer").font(.title3); if e.intervalOn { Text("\(e.intervalN)").font(.system(size: 9, design: .monospaced)).foregroundColor(.green) } }
                                .frame(width: 44, height: 44).foregroundColor(e.intervalOn ? .green : .secondary)
                            }
                        }.frame(width: 64)

                        Spacer()

                        Button { e.capture() } label: {
                            ZStack {
                                Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                                if e.isCapturing { ProgressView().tint(.white).scaleEffect(1.3) }
                                else { Circle().fill(.red).frame(width: 60, height: 60) }
                            }
                        }.disabled(e.isCapturing)

                        Spacer()

                        VStack(spacing: 18) {
                            Button { e.evUp() } label: { Image(systemName: "plus.circle.fill").font(.title3).frame(width: 44, height: 44).foregroundColor(.secondary) }
                            Button { e.evDown() } label: { Image(systemName: "minus.circle.fill").font(.title3).frame(width: 44, height: 44).foregroundColor(.secondary) }
                            Button { e.toggleFocusLock() } label: { Image(systemName: e.isManualFocus ? "target" : "scope").font(.title3).frame(width: 44, height: 44).foregroundColor(e.isManualFocus ? .red : .secondary) }
                        }.frame(width: 64)
                    }.padding(.horizontal, 16).padding(.bottom, 40)
                }
                .gesture(DragGesture(minimumDistance: 0).onEnded { g in e.focusAt(pt: g.location, size: geo.size) })
            }
        }
        .task { await e.start() }
    }
}
