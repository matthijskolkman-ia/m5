import SwiftUI
import AVFoundation
import Photos
import PhotosUI

// MARK: - App

@main
struct SloMoLabApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
        }
    }
}

// MARK: - Mode

enum CameraMode: String, CaseIterable {
    case slomo = "Slow-Mo"
    case live = "Live Photo"
}

// MARK: - Models

struct SloMoMode: Identifiable {
    let id = UUID()
    let label: String          // "4K @ 240 fps"
    let detail: String         // "3840×2160 · HDR"
    let format: AVCaptureDevice.Format
    let fps: Int
    let isHDR: Bool
}

// MARK: - Camera Engine

@MainActor
final class CameraEngine: NSObject, ObservableObject {
    @Published var modes: [SloMoMode] = []
    @Published var activeMode: SloMoMode?
    @Published var isRecording = false
    @Published var status: String = "Requesting camera..."
    @Published var isReady = false

    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let videoOutput = AVCaptureMovieFileOutput()
    private var device: AVCaptureDevice?

    // ── Setup ──

    func start() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            status = "Camera denied. Enable in Settings."
            return
        }

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            status = "No rear camera."
            return
        }
        device = cam

        do {
            let input = try AVCaptureDeviceInput(device: cam)
            session.beginConfiguration()
            session.sessionPreset = .high
            if session.canAddInput(input) { session.addInput(input) }
            if let mic = AVCaptureDevice.default(for: .audio),
               let micIn = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(micIn) { session.addInput(micIn) }
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            session.commitConfiguration()
        } catch {
            status = "Camera error: \(error.localizedDescription)"
            return
        }

        scanModes(cam)
        status = modes.isEmpty ? "No slow-mo formats" : "Ready"

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        // Start on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            Task { @MainActor in self.isReady = true }
        }
    }

    // ── Scan formats ──

    private func scanModes(_ cam: AVCaptureDevice) {
        var found: [SloMoMode] = []

        for fmt in cam.formats {
            let dims = fmt.formatDescription.dimensions
            for range in fmt.videoSupportedFrameRateRanges where range.maxFrameRate >= 120 {
                let fps = Int(range.maxFrameRate)
                let dw = Int(dims.width), dh = Int(dims.height)
                guard !found.contains(where: {
                    $0.fps == fps
                    && $0.format.formatDescription.dimensions.width == dims.width
                    && $0.format.formatDescription.dimensions.height == dims.height
                }) else { continue }

                let w = dims.width, h = dims.height
                let res: String = w == 3840 ? "4K" : w == 1920 ? "1080p" : w == 1280 ? "720p" : "\(w)×\(h)"
                let hdr = fmt.isVideoHDRSupported ? " HDR" : ""

                found.append(SloMoMode(
                    label: "\(res) @ \(fps) fps",
                    detail: "\(w)×\(h) · max \(fps) fps\(hdr)",
                    format: fmt,
                    fps: fps,
                    isHDR: fmt.isVideoHDRSupported
                ))
            }
        }

        found.sort {
            let pa = $0.format.formatDescription.dimensions.width * $0.format.formatDescription.dimensions.height
            let pb = $1.format.formatDescription.dimensions.width * $1.format.formatDescription.dimensions.height
            return pa != pb ? pa > pb : $0.fps > $1.fps
        }

        modes = found
        activeMode = found.first
    }

    // ── Switch format ──

    func select(_ mode: SloMoMode) {
        guard let cam = device else { return }
        do {
            try cam.lockForConfiguration()
            cam.activeFormat = mode.format
            cam.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(mode.fps))
            cam.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(mode.fps))
            cam.unlockForConfiguration()
            activeMode = mode
        } catch {
            status = "Switch failed: \(error.localizedDescription)"
        }
    }

    // ── Record ──

    func toggleRecord() {
        if isRecording {
            videoOutput.stopRecording()
            isRecording = false
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("slomo_\(Int(Date().timeIntervalSince1970)).mov")
            videoOutput.startRecording(to: url, recordingDelegate: self)
            isRecording = true
        }
    }

}

// MARK: - Recording Delegate

extension CameraEngine: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                 didFinishRecordingTo url: URL,
                                 from connections: [AVCaptureConnection],
                                 error: Error?) {
        Task { @MainActor in
            isRecording = false
            if let error {
                status = "Record error: \(error.localizedDescription)"
            } else {
                status = "Saved!"
                UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
            }
        }
    }
}

// MARK: - Live Photo Engine

@MainActor
final class LivePhotoEngine: NSObject, ObservableObject {
    @Published var capturedLivePhoto: PHLivePhoto?
    @Published var status = "Ready"
    @Published var isCapturing = false
    @Published var info: String?

    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let photoOutput = AVCapturePhotoOutput()

    func start() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { status = "Camera denied"; return }

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            status = "No camera"; return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        if let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) {
            session.addInput(input)
        }
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
        status = "Live Photo ready"
    }

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        status = "Capturing..."

        let settings = AVCapturePhotoSettings()
        settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("live_\(Int(Date().timeIntervalSince1970)).mov")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension LivePhotoEngine: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingLivePhotoToMovieFileAt url: URL,
                                  duration: CMTime,
                                  photoDisplayTime: CMTime,
                                  resolvedSettings: AVCaptureResolvedPhotoSettings,
                                  error: Error?) {
        Task { @MainActor in
            guard error == nil else {
                status = "Live Photo error: \(error!.localizedDescription)"
                isCapturing = false
                return
            }

            PHLivePhoto.request(withResourceFileURLs: [url],
                                placeholderImage: nil,
                                targetSize: .zero,
                                contentMode: .default) { [weak self] photo, _ in
                Task { @MainActor in
                    self?.capturedLivePhoto = photo
                    self?.isCapturing = false
                    self?.status = "Captured!"
                    self?.info = "Duration: \(String(format: "%.1f", duration.seconds))s"
                }
            }
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingPhoto photo: AVCapturePhoto,
                                  error: Error?) {
        // Still frame — we don't use it separately for Live Photos
    }
}

// MARK: - Live Photo View

struct LivePhotoView: UIViewRepresentable {
    let photo: PHLivePhoto?

    func makeUIView(context: Context) -> PHLivePhotoView {
        let v = PHLivePhotoView()
        v.contentMode = .scaleAspectFit
        return v
    }

    func updateUIView(_ v: PHLivePhotoView, context: Context) {
        v.livePhoto = photo
        if photo != nil { v.startPlayback(with: .hint) }
    }
}

// MARK: - Preview

final class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet { oldValue?.removeFromSuperlayer()
                 if let l = previewLayer { layer.addSublayer(l) } }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

struct Preview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer = layer
        return v
    }

    func updateUIView(_ v: PreviewView, context: Context) {}
}

// MARK: - UI

struct CameraView: View {
    @StateObject private var sloMo = CameraEngine()
    @StateObject private var livePhoto = LivePhotoEngine()
    @State private var mode: CameraMode = .slomo

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Preview — always the active engine's preview
            Preview(layer: mode == .slomo ? sloMo.previewLayer : livePhoto.previewLayer).ignoresSafeArea()

            VStack(spacing: 0) {
                // Mode switch
                Picker("Mode", selection: $mode) {
                    ForEach(CameraMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                .padding(.top, 60)

                // Status
                Text(mode == .slomo ? sloMo.status : livePhoto.status)
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .padding(.top, 8)

                Spacer()

                if mode == .slomo {
                    slomoControls
                } else {
                    livePhotoControls
                }
            }
        }
        .task {
            await sloMo.start()
            await livePhoto.start()
        }
    }

    // ── Slow-Mo Controls ──

    @ViewBuilder
    var slomoControls: some View {
        if !sloMo.modes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sloMo.modes) { mode in
                        Button { sloMo.select(mode) } label: {
                            VStack(spacing: 2) {
                                Text(mode.label)
                                    .font(.system(size: 11, design: .monospaced)).fontWeight(.medium)
                                Text(mode.detail)
                                    .font(.system(size: 9, design: .monospaced))
                            }
                            .foregroundColor(mode.id == sloMo.activeMode?.id ? .white : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background((mode.id == sloMo.activeMode?.id ? Color.white : Color.white)
                                .opacity(mode.id == sloMo.activeMode?.id ? 0.15 : 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        Button { sloMo.toggleRecord() } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 72, height: 72)
                if sloMo.isRecording {
                    RoundedRectangle(cornerRadius: 6).fill(.red).frame(width: 28, height: 28)
                } else {
                    Circle().fill(.red).frame(width: 56, height: 56)
                }
            }
        }
        .padding(.bottom, 40)
    }

    // ── Live Photo Controls ──

    @ViewBuilder
    var livePhotoControls: some View {
        if let photo = livePhoto.capturedLivePhoto {
            // Show captured live photo
            VStack(spacing: 12) {
                LivePhotoView(photo: photo)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let info = livePhoto.info {
                    Text(info)
                        .font(.caption).foregroundColor(.secondary)
                }

                Button {
                    livePhoto.capturedLivePhoto = nil
                    livePhoto.info = nil
                    livePhoto.status = "Live Photo ready"
                } label: {
                    Label("Capture New", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        } else {
            VStack(spacing: 8) {
                Text("Hold still — Live Photo captures\n1.5s before + after the shutter")
                    .font(.caption).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    livePhoto.capture()
                } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 72, height: 72)
                        if livePhoto.isCapturing {
                            ProgressView().tint(.white)
                        } else {
                            Circle().fill(.white).frame(width: 56, height: 56)
                        }
                    }
                }
                .disabled(livePhoto.isCapturing)
            }
            .padding(.bottom, 40)
        }
    }
}
