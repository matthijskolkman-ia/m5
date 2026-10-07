import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

// MARK: - App

@main
struct SimilaritiesApp: App {
    var body: some Scene {
        WindowGroup {
            SimView()
                .frame(minWidth: 420, minHeight: 360)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 400)
    }
}

// MARK: - Dup Group

struct DupGroup: Identifiable {
    let id = UUID()
    let hash: String
    let size: Int64
    var files: [URL]
    var wastedBytes: Int64 { size * Int64(files.count - 1) }
    var isKept: Set<Int> = [0]  // indices of files to keep
}

// MARK: - View

struct SimView: View {
    @State private var groups: [DupGroup] = []
    @State private var isScanning = false
    @State private var status = "Drop a folder here"
    @State private var totalWasted: Int64 = 0
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🔍 Similarities").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
                Spacer()
                if isScanning {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                }
                Text(groups.isEmpty ? "" : "\(groups.count) dups · \(formatBytes(totalWasted)) wasted")
                    .font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.25))
            }.padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

            // Content
            if groups.isEmpty && !isScanning {
                // Drop zone
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(isTargeted ? Color.blue : Color.white.opacity(0.06), lineWidth: isTargeted ? 2 : 1))
                    VStack(spacing: 10) {
                        Image(systemName: "doc.on.doc").font(.system(size: 32)).foregroundColor(.white.opacity(0.15))
                        Text("Drop a folder to find duplicates")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                        Text("Scans by content hash (SHA256)")
                            .font(.system(size: 8)).foregroundColor(.white.opacity(0.15))
                    }
                }
                .frame(height: 200).padding(10)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    if let p = providers.first {
                        p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                                DispatchQueue.main.async { scan(url) }
                            }
                        }
                    }
                    return true
                }
            } else {
                // Results
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(groups) { group in
                            DupRow(group: group, onDelete: { url in deleteFile(url, from: group.id) })
                        }
                    }.padding(8)
                }
            }

            // Bottom bar
            if !groups.isEmpty || isScanning {
                HStack {
                    Text(status).font(.system(size: 8)).foregroundColor(.white.opacity(0.3))
                    Spacer()
                    if !groups.isEmpty {
                        Button("Delete All Duplicates") { deleteAllDups() }
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.red.opacity(0.1)).clipShape(Capsule())
                    }
                    Button(action: { groups = []; totalWasted = 0; status = "Drop a folder" }) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 10).padding(.bottom, 6).padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
    }

    // MARK: - Scan

    func scan(_ root: URL) {
        isScanning = true
        status = "Scanning..."
        groups = []

        DispatchQueue.global(qos: .userInitiated).async {
            var hashMap: [String: [URL]] = [:]
            var sizes: [String: Int64] = [:]
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey])

            while let url = enumerator?.nextObject() as? URL {
                guard let res = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      res.isRegularFile == true,
                      let size = res.fileSize, size > 0 else { continue }

                // Read first 8KB for fast hashing
                let handle = try? FileHandle(forReadingFrom: url)
                let prefix = handle?.readData(ofLength: 8192) ?? Data()
                try? handle?.close()
                guard !prefix.isEmpty else { continue }

                let hash = SHA256.hash(data: prefix).compactMap { String(format: "%02x", $0) }.joined()
                hashMap[hash, default: []].append(url)
                sizes[hash] = Int64(size)
            }

            var dups: [DupGroup] = []
            var waste: Int64 = 0
            for (hash, files) in hashMap where files.count > 1 {
                let size = sizes[hash] ?? 0
                let group = DupGroup(hash: String(hash.prefix(8)), size: size, files: files)
                dups.append(group)
                waste += group.wastedBytes
            }
            dups.sort { $0.wastedBytes > $1.wastedBytes }

            DispatchQueue.main.async {
                groups = dups
                totalWasted = waste
                isScanning = false
                status = dups.isEmpty ? "No duplicates found" : "Found \(dups.count) duplicate groups"
            }
        }
    }

    func deleteFile(_ url: URL, from groupID: UUID) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        if let i = groups.firstIndex(where: { $0.id == groupID }) {
            groups[i].files.removeAll { $0 == url }
            if groups[i].files.count < 2 { groups.remove(at: i) }
        }
        recalcWaste()
    }

    func deleteAllDups() {
        for group in groups {
            for (i, url) in group.files.enumerated() where i > 0 {
                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
        }
        groups = []
        totalWasted = 0
        status = "All duplicates trashed"
    }

    func recalcWaste() {
        totalWasted = groups.reduce(0) { $0 + $1.wastedBytes }
    }

    func formatBytes(_ b: Int64) -> String {
        if b > 1_000_000_000 { return String(format: "%.1f GB", Double(b)/1_000_000_000) }
        if b > 1_000_000 { return String(format: "%.1f MB", Double(b)/1_000_000) }
        return "\(b/1000) KB"
    }
}

// MARK: - Dup Row

struct DupRow: View {
    let group: DupGroup
    let onDelete: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(group.files.count)×").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Text(formatBytes(group.size)).font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text("each · \(formatBytes(group.wastedBytes)) wasted")
                    .font(.system(size: 8)).foregroundColor(.red.opacity(0.5))
                Spacer()
            }.padding(.horizontal, 10).padding(.vertical, 4)

            ForEach(Array(group.files.enumerated()), id: \.offset) { i, url in
                HStack {
                    Text(i == 0 ? "✓" : "  ").font(.system(size: 8, design: .monospaced))
                        .foregroundColor(i == 0 ? .green : .clear).frame(width: 14)
                    Text(url.lastPathComponent).font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6)).lineLimit(1)
                    Spacer()
                    if i > 0 {
                        Button(action: { onDelete(url) }) {
                            Image(systemName: "trash").font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.2))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 10).padding(.vertical, 2)
            }

            Divider().background(Color.white.opacity(0.04)).padding(.horizontal, 10)
        }
    }

    func formatBytes(_ b: Int64) -> String {
        if b > 1_000_000_000 { return String(format: "%.1f GB", Double(b)/1_000_000_000) }
        if b > 1_000_000 { return String(format: "%.1f MB", Double(b)/1_000_000) }
        return "\(b/1000) KB"
    }
}
