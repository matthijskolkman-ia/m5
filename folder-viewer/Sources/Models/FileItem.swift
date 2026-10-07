import Foundation
import AppKit

// MARK: - File Item

struct FileItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let fileSize: Int64?
    let modificationDate: Date?
    let kind: String
    let icon: NSImage

    static func from(url: URL) -> FileItem {
        let res = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .isPackageKey, .fileSizeKey,
            .contentModificationDateKey, .localizedTypeDescriptionKey,
            .effectiveIconKey
        ])

        let isDir = res?.isDirectory ?? false
        let isPkg = res?.isPackage ?? false

        return FileItem(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDir,
            isPackage: isPkg,
            fileSize: res?.fileSize.map(Int64.init),
            modificationDate: res?.contentModificationDate,
            kind: res?.localizedTypeDescription ?? (isDir ? "Folder" : "File"),
            icon: res?.effectiveIcon as? NSImage ?? NSWorkspace.shared.icon(forFile: url.path)
        )
    }

    /// Human-readable file size
    var sizeDisplay: String {
        guard let size = fileSize, !isDirectory else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Formatted date
    var dateDisplay: String {
        guard let date = modificationDate else { return "--" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}
