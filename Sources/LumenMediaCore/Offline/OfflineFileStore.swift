import Foundation

/// On-disk layout for offline media files.
///
/// `<Application Support>/offline_media/<mediaId>.partial` while downloading,
/// renamed to `<mediaId>.<ext>` when complete.
public final class OfflineFileStore: @unchecked Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.root = base.appendingPathComponent("offline_media", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    public func partialFile(mediaId: String) -> URL {
        root.appendingPathComponent("\(mediaId).partial")
    }

    public func readyFile(mediaId: String, extension ext: String) -> URL {
        let cleaned = ext.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        let safe = cleaned.isEmpty ? "bin" : cleaned
        return root.appendingPathComponent("\(mediaId).\(safe)")
    }

    public func findReadyFile(mediaId: String) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        let matches = files.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("\(mediaId).") && !name.hasSuffix(".partial")
        }
        return matches.max { a, b in
            let sizeA = (try? a.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let sizeB = (try? b.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sizeA < sizeB
        }
    }

    public func deleteMediaFiles(mediaId: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in files where url.lastPathComponent == "\(mediaId).partial"
            || url.lastPathComponent.hasPrefix("\(mediaId).")
        {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func deleteAll() {
        if FileManager.default.fileExists(atPath: root.path) {
            try? FileManager.default.removeItem(at: root)
        }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func totalBytesOnDisk() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
