import Foundation

/// JSON-backed metadata store for offline downloads.
public final class OfflineCacheStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var items: [String: OfflineCachedItem] = [:]

    public init(directory: URL? = nil) {
        let dir = directory ?? (
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        ).appendingPathComponent("offline_media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("cache_index.json")
        load()
    }

    public func all() -> [OfflineCachedItem] {
        lock.lock(); defer { lock.unlock() }
        return items.values.sorted { $0.updatedAtEpochMs > $1.updatedAtEpochMs }
    }

    public func get(_ mediaId: String) -> OfflineCachedItem? {
        lock.lock(); defer { lock.unlock() }
        return items[mediaId]
    }

    public func list(status: CachedMediaStatus) -> [OfflineCachedItem] {
        lock.lock(); defer { lock.unlock() }
        return items.values.filter { $0.status == status }
            .sorted { $0.updatedAtEpochMs < $1.updatedAtEpochMs }
    }

    public func readyBytes() -> Int64 {
        lock.lock(); defer { lock.unlock() }
        return items.values
            .filter { $0.status == .ready }
            .reduce(0) { $0 + max($1.bytesTotal, $1.bytesDownloaded) }
    }

    public func upsert(_ item: OfflineCachedItem) {
        lock.lock()
        items[item.mediaId] = item
        lock.unlock()
        persist()
    }

    public func delete(_ mediaId: String) {
        lock.lock()
        items.removeValue(forKey: mediaId)
        lock.unlock()
        persist()
    }

    public func deleteAll() {
        lock.lock()
        items.removeAll()
        lock.unlock()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([OfflineCachedItem].self, from: data)
        else { return }
        items = Dictionary(uniqueKeysWithValues: decoded.map { ($0.mediaId, $0) })
    }

    private func persist() {
        lock.lock()
        let snapshot = Array(items.values)
        lock.unlock()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
