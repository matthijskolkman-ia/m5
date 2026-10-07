import SwiftUI
import AVFoundation

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var connectivity: iOSConnectivity
    @EnvironmentObject var proximity: ProximityTracker
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                statusBar

                // Main area
                if let image = capturedImage {
                    CardFormView(
                        image: image,
                        onRetake: { capturedImage = nil; showCamera = true },
                        onSend: { name, number, rarity, holo, revHolo, condition in
                            let imgData = image.jpegData(compressionQuality: 0.7)
                            connectivity.sendCard(
                                name: name, cardNumber: number, rarity: rarity,
                                isHolo: holo, isReverseHolo: revHolo,
                                condition: condition, imageData: imgData
                            )
                        }
                    )
                } else {
                    // Welcome / prompt
                    VStack(spacing: 24) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("CardVault Camera")
                            .font(.title.bold())

                        Text("Take a photo of a Pokémon card\nto add it to your collection on Mac.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        Button(action: { showCamera = true }) {
                            Label("Scan Card", systemImage: "camera.fill")
                                .font(.headline)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("CardVault")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(capturedImage: $capturedImage)
        }
        .onAppear {
            proximity.start()
        }
    }

    var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectivity.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(connectivity.statusMessage)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            if let d = proximity.distanceMeters {
                Text("📡 \(proximity.distanceText)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(d < 1.0 ? .green : .orange)
                    .padding(.leading, 4)
            }

            Spacer()

            if !connectivity.isConnected {
                Button("Retry") {
                    connectivity.stopBrowsing()
                    connectivity.startBrowsing()
                }
                .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
        .overlay(
            Rectangle().fill(Color(.separator)).frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Camera View

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var capturedImage: UIImage?

    var body: some View {
        ZStack {
            CameraPreview(capturedImage: $capturedImage, onCapture: {
                dismiss()
            })

            VStack {
                Spacer()
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 40)
                    .padding(.bottom, 40)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }
}

// MARK: - UIKit Camera Preview

struct CameraPreview: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    let onCapture: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraPreview
        init(_ parent: CameraPreview) { self.parent = parent }

        func didCapture(image: UIImage) {
            parent.capturedImage = image
            parent.onCapture()
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didCapture(image: UIImage)
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else { return }

        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Capture button
        let button = UIButton(type: .system)
        button.frame = CGRect(x: (view.bounds.width - 70) / 2, y: view.bounds.height - 120, width: 70, height: 70)
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(button)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    @objc func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        delegate?.didCapture(image: image)
    }
}

// MARK: - Card Form View

struct CardFormView: View {
    @EnvironmentObject var connectivity: iOSConnectivity
    let image: UIImage
    let onRetake: () -> Void
    let onSend: (String, String, String, Bool, Bool, String) -> Void

    @StateObject private var scanner = CardScanner()
    @State private var name = ""
    @State private var cardNumber = ""
    @State private var selectedRarity = "● Common"
    @State private var isHolo = false
    @State private var isReverseHolo = false
    @State private var selectedCondition = "Mint"
    @State private var isSending = false
    @State private var hasScanned = false

    let rarities = CardRarity.allCases.map(\.rawValue)
    let conditions = ["Mint", "Near Mint", "Excellent", "Good", "Played"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Image preview
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .cornerRadius(12)

                    // Scanning overlay
                    if scanner.isScanning {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black.opacity(0.6))

                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                                Text("Scanning card...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Reading text & searching database")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }

                    // Retake button
                    if !scanner.isScanning {
                        Button(action: onRetake) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 14))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
                }

                // Scan result banner
                if let result = scanner.scannedResult {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "sparkle.magnifyingglass")
                                .foregroundColor(.green)
                            Text("Found: \(result.name)")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        Text("\(result.set) · \(result.rarity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let price = result.marketPrice {
                            Text("Market: $\(String(format: "%.2f", price))")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                // Card / Pokémon verification banner
                if let v = scanner.verification {
                    HStack(spacing: 10) {
                        Image(systemName: v.verdict == .pokemonCard ? "checkmark.seal.fill" :
                                      v.verdict == .maybeCard ? "questionmark.diamond.fill" :
                                      "exclamationmark.triangle.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.verdict.rawValue)
                                .font(.subheadline.bold())
                            Text("Confidence \(Int(v.confidence * 100))% — \(v.details)")
                                .font(.caption2)
                        }
                        Spacer()
                    }
                    .foregroundColor(verificationColor(v.verdict))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(verificationColor(v.verdict).opacity(0.12))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Error banner
                if let error = scanner.errorMessage {
                    HStack {
                        Image(systemName: "info.circle")
                        Text(error)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // Debug: show what OCR saw
                if let debug = scanner.debugOCRText, !debug.isEmpty {
                    DisclosureGroup {
                        Text(debug)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    } label: {
                        Label("OCR Debug (tap to see what was read)", systemImage: "eye")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Form fields
                VStack(spacing: 12) {
                    HStack {
                        TextField("Card name (e.g. Pikachu)", text: $name)
                            .textFieldStyle(.roundedBorder)
                        if scanner.isScanning {
                            ProgressView().scaleEffect(0.7)
                        }
                    }

                    HStack {
                        TextField("Card number (e.g. 25/165)", text: $cardNumber)
                            .textFieldStyle(.roundedBorder)
                        if scanner.isScanning {
                            ProgressView().scaleEffect(0.7)
                        }
                    }

                    Picker("Rarity", selection: $selectedRarity) {
                        ForEach(rarities, id: \.self) { r in Text(r).tag(r) }
                    }
                    .pickerStyle(.menu)

                    Picker("Condition", selection: $selectedCondition) {
                        ForEach(conditions, id: \.self) { c in Text(c).tag(c) }
                    }
                    .pickerStyle(.menu)

                    Toggle("Holo ✨", isOn: $isHolo)
                    Toggle("Reverse Holo 🔄", isOn: $isReverseHolo)
                }
                .padding(.horizontal)

                // Send button
                Button(action: {
                    isSending = true
                    onSend(name, cardNumber, selectedRarity, isHolo, isReverseHolo, selectedCondition)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isSending = false }
                }) {
                    HStack {
                        if isSending {
                            ProgressView().tint(.white)
                        }
                        Text(isSending ? "Sending..." : "Send to Mac")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(name.isEmpty || isSending)
                .padding(.horizontal)

                // Confirmation
                if let confirm = connectivity.lastConfirmation {
                    Text(confirm)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.bottom)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            if !hasScanned {
                hasScanned = true
                scanner.scanCard(from: image)
            }
        }
        .onChange(of: scanner.scannedResult?.id) { _, _ in
            if let result = scanner.scannedResult {
                withAnimation {
                    name = result.name
                    cardNumber = result.cardNumber
                    selectedRarity = result.rarity
                    isHolo = result.isHolo
                }
            }
        }
    }

    func verificationColor(_ verdict: CardVerification.Verdict) -> Color {
        switch verdict {
        case .pokemonCard: return .green
        case .maybeCard: return .orange
        case .notACard: return .red
        }
    }
}

// MARK: - Rarity enum (mirrors Mac model)

enum CardRarity: String, CaseIterable {
    case common = "● Common"
    case uncommon = "◆ Uncommon"
    case rare = "★ Rare"
    case doubleRare = "★★ Double Rare"
    case ultraRare = "💎 Ultra Rare"
    case illustrationRare = "🎨 Illustration Rare"
    case specialIllustrationRare = "🌟 Special Illustration Rare"
    case hyperRare = "🌈 Hyper Rare"
    case promo = "⭐ Promo"
    case energy = "⚡ Energy"
    case trainer = "🏷 Trainer"
}
