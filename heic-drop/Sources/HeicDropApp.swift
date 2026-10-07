import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - App

@main
struct HeicDropApp: App {
    var body: some Scene {
        WindowGroup {
            DropView()
                .frame(minWidth: 300, maxWidth: 300, minHeight: 240, maxHeight: 240)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 240)
    }
}

// MARK: - Format

enum OutFormat: String, CaseIterable {
    case png, jpg
    var ext: String { rawValue }
    var utType: UTType {
        switch self { case .png: .png; case .jpg: .jpeg }
    }
}

// MARK: - View

struct DropView: View {
    @State private var isTargeted = false
    @State private var format: OutFormat = .png
    @State private var logs: [String] = []
    @State private var totalConverted = 0

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("📸 HeicDrop").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(totalConverted) done").font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.2))
            }.padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

            // Format picker
            HStack(spacing: 3) {
                ForEach(OutFormat.allCases, id: \.self) { f in
                    Button { format = f } label: {
                        Text(f.ext.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(format == f ? .white : .white.opacity(0.3))
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                            .background(format == f ? Color.blue.opacity(0.2) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 8)

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isTargeted ? Color.blue : Color.white.opacity(0.08), lineWidth: isTargeted ? 2 : 1))

                VStack(spacing: 8) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "photo.on.rectangle")
                        .font(.system(size: 28))
                        .foregroundColor(isTargeted ? .blue : .white.opacity(0.2))
                    Text(isTargeted ? "Drop to convert" : "Drag HEIC files here")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(isTargeted ? 0.7 : 0.25))
                    Text("Converts to \(format.ext.uppercased())")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.15))
                }
            }
            .frame(height: 100).padding(.horizontal, 8).padding(.vertical, 4)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                for p in providers {
                    p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        if let data = item as? Data,
                           let url = URL(dataRepresentation: data, relativeTo: nil) {
                            DispatchQueue.main.async { convert(url) }
                        }
                    }
                }
                return true
            }

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
                    }.frame(height: 32)
                    .onChange(of: logs) { _, _ in if let last = logs.last { sv.scrollTo(last) } }
                }
            }

            Spacer(minLength: 4)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
    }

    func convert(_ url: URL) {
        guard let src = NSImage(contentsOf: url) else {
            logs.append("❌ Can't read \(url.lastPathComponent)")
            return
        }
        guard let tiff = src.tiffRepresentation, let img = NSBitmapImageRep(data: tiff) else {
            logs.append("❌ Failed \(url.lastPathComponent)")
            return
        }

        let stem = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()
        let outURL = dir.appendingPathComponent("\(stem).\(format.ext)")

        let data: Data?
        switch format {
        case .png:
            data = img.representation(using: .png, properties: [:])
        case .jpg:
            data = img.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
        }

        guard let data, let _ = try? data.write(to: outURL) else {
            logs.append("❌ Write failed")
            return
        }

        totalConverted += 1
        logs.append("✅ \(url.lastPathComponent) → \(stem).\(format.ext)")
    }
}
