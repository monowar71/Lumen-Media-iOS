import Foundation
import Combine

/// Queues and downloads original media via `GET /api/v1/items/{id}/download`.
///
/// One download at a time to keep the device usable for streaming.
@MainActor
public final class OfflineDownloadManager: ObservableObject {
    @Published public private(set) var entries: [OfflineCachedItem] = []
    @Published public private(set) var summary = OfflineCacheSummary()

    private let store: OfflineCacheStore
    private let files: OfflineFileStore
    private let settingsStore: SettingsStore
    private let sessionStore: SessionStore

    private var cancelFlags: [String: Bool] = [:]
    private var wakeContinuations: [CheckedContinuation<Void, Never>] = []
    private var activeDownloadTask: URLSessionDownloadTask?

    public static let defaultMaxCacheBytes: Int64 = AppSettings.defaultMaxCacheBytes

    public init(
        settingsStore: SettingsStore,
        sessionStore: SessionStore,
        store: OfflineCacheStore = OfflineCacheStore(),
        files: OfflineFileStore = OfflineFileStore()
    ) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.store = store
        self.files = files
        refreshPublished()
        Task { await recoverInterruptedDownloads() }
        Task { await workerLoop() }
    }

    public func stateFor(_ mediaId: String) -> OfflineCachedItem? {
        entries.first { $0.mediaId == mediaId }
    }

    public func readyFileURL(for mediaId: String) -> URL? {
        if let item = stateFor(mediaId), item.status == .ready {
            if let path = item.localPath {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }
        return files.findReadyFile(mediaId: mediaId)
    }

    public func enqueue(_ request: OfflineEnqueueRequest) async {
        if let existing = store.get(request.mediaId),
           existing.status == .ready || existing.status == .downloading || existing.status == .queued
        {
            return
        }
        await enforceBudgetIfNeeded(estimatedNewBytes: 0)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let created = store.get(request.mediaId)?.createdAtEpochMs ?? now
        store.upsert(
            OfflineCachedItem(
                mediaId: request.mediaId,
                kind: request.kind,
                seriesId: request.seriesId,
                seasonId: request.seasonId,
                title: request.title,
                seasonNumber: request.seasonNumber,
                episodeNumber: request.episodeNumber,
                episodeTitle: request.episodeTitle,
                status: .queued,
                updatedAtEpochMs: now,
                createdAtEpochMs: created
            )
        )
        refreshPublished()
        wakeWorker()
    }

    public func enqueueSeason(
        seriesId: String,
        seriesTitle: String,
        seasonId: String,
        episodes: [EpisodeSummary]
    ) async {
        for episode in episodes {
            await enqueue(
                .episode(
                    from: episode,
                    seriesId: seriesId,
                    seriesTitle: seriesTitle,
                    seasonId: seasonId
                )
            )
        }
    }

    public func cancel(_ mediaId: String) async {
        cancelFlags[mediaId] = true
        if activeDownloadTask != nil, store.get(mediaId)?.status == .downloading {
            activeDownloadTask?.cancel()
        }
        guard let current = store.get(mediaId) else { return }
        if current.status == .queued {
            await remove(mediaId)
        }
    }

    public func remove(_ mediaId: String) async {
        cancelFlags[mediaId] = true
        if store.get(mediaId)?.status == .downloading {
            activeDownloadTask?.cancel()
        }
        files.deleteMediaFiles(mediaId: mediaId)
        store.delete(mediaId)
        cancelFlags.removeValue(forKey: mediaId)
        refreshPublished()
    }

    public func clearAll() async {
        for item in store.all() {
            cancelFlags[item.mediaId] = true
        }
        activeDownloadTask?.cancel()
        files.deleteAll()
        store.deleteAll()
        cancelFlags.removeAll()
        refreshPublished()
    }

    public func removeFailed() async {
        for item in store.list(status: .failed) {
            await remove(item.mediaId)
        }
    }

    // MARK: - Worker

    private func workerLoop() async {
        while true {
            if let next = store.list(status: .queued).first {
                await downloadOne(next)
                continue
            }
            await waitForWake()
        }
    }

    private func waitForWake() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            wakeContinuations.append(cont)
        }
    }

    private func wakeWorker() {
        let pending = wakeContinuations
        wakeContinuations.removeAll()
        pending.forEach { $0.resume() }
    }

    private func recoverInterruptedDownloads() async {
        for entity in store.list(status: .downloading) {
            files.deleteMediaFiles(mediaId: entity.mediaId)
            var queued = entity
            queued.status = .queued
            queued.bytesDownloaded = 0
            queued.bytesTotal = 0
            queued.localPath = nil
            queued.errorMessage = nil
            queued.updatedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
            store.upsert(queued)
        }
        refreshPublished()
        wakeWorker()
    }

    private func downloadOne(_ entity: OfflineCachedItem) async {
        cancelFlags[entity.mediaId] = false
        let partial = files.partialFile(mediaId: entity.mediaId)
        try? FileManager.default.removeItem(at: partial)

        var working = entity
        working.status = .downloading
        working.bytesDownloaded = 0
        working.bytesTotal = 0
        working.localPath = partial.path
        working.errorMessage = nil
        working.updatedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
        store.upsert(working)
        refreshPublished()

        do {
            await enforceBudgetIfNeeded(estimatedNewBytes: 0)
            let baseUrl = UrlUtils.normalizeBaseUrl(settingsStore.currentSettings.baseUrl)
            var urlString = "\(baseUrl)/api/v1/items/\(entity.mediaId)/download"
            urlString = UrlUtils.withAccessToken(urlString, token: sessionStore.accessToken)
            guard let url = URL(string: urlString) else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if let token = sessionStore.accessToken, !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let result = try await performDownload(
                request: request,
                mediaId: entity.mediaId
            ) { [weak self] written, total in
                Task { @MainActor in
                    guard let self else { return }
                    var item = working
                    item.status = .downloading
                    item.bytesDownloaded = written
                    item.bytesTotal = total > 0 ? total : item.bytesTotal
                    item.localPath = partial.path
                    item.updatedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
                    working = item
                    self.store.upsert(item)
                    self.refreshPublished()
                }
            }

            if cancelFlags[entity.mediaId] == true {
                throw DownloadCancelled()
            }

            if result.total > 0 {
                await enforceBudgetIfNeeded(estimatedNewBytes: result.total)
            }

            let extensionName = Self.guessExtension(
                contentType: result.contentType,
                contentDisposition: result.contentDisposition
            )
            try? FileManager.default.removeItem(at: partial)
            try FileManager.default.moveItem(at: result.tempURL, to: partial)

            let ready = files.readyFile(mediaId: entity.mediaId, extension: extensionName)
            try? FileManager.default.removeItem(at: ready)
            do {
                try FileManager.default.moveItem(at: partial, to: ready)
            } catch {
                try FileManager.default.copyItem(at: partial, to: ready)
                try? FileManager.default.removeItem(at: partial)
            }

            let downloaded = (try? FileManager.default.attributesOfItem(atPath: ready.path)[.size] as? Int64) ?? result.written
            working.status = .ready
            working.bytesDownloaded = downloaded
            working.bytesTotal = result.total > 0 ? result.total : downloaded
            working.localPath = ready.path
            working.container = extensionName
            working.errorMessage = nil
            working.updatedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
            store.upsert(working)
            await enforceBudgetIfNeeded(estimatedNewBytes: 0)
            refreshPublished()
        } catch is DownloadCancelled {
            files.deleteMediaFiles(mediaId: entity.mediaId)
            store.delete(entity.mediaId)
            refreshPublished()
        } catch let error as URLError where error.code == .cancelled {
            files.deleteMediaFiles(mediaId: entity.mediaId)
            store.delete(entity.mediaId)
            refreshPublished()
        } catch {
            files.deleteMediaFiles(mediaId: entity.mediaId)
            working.status = .failed
            working.bytesDownloaded = 0
            working.localPath = nil
            working.errorMessage = error.lumenUserMessage("Download failed")
            working.updatedAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
            store.upsert(working)
            refreshPublished()
        }

        activeDownloadTask = nil
        cancelFlags.removeValue(forKey: entity.mediaId)
    }

    private func performDownload(
        request: URLRequest,
        mediaId: String,
        onProgress: @escaping (Int64, Int64) -> Void
    ) async throws -> DownloadResultBox {
        let delegate = DownloadTaskDelegate(onProgress: onProgress)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 6
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            let task = session.downloadTask(with: request)
            self.activeDownloadTask = task
            if self.cancelFlags[mediaId] == true {
                task.cancel()
            }
            task.resume()
        }
    }

    private func enforceBudgetIfNeeded(estimatedNewBytes: Int64) async {
        let maxBytes = settingsStore.currentSettings.maxCacheBytes
        if maxBytes <= 0 { return }
        var used = store.readyBytes() + estimatedNewBytes
        if used <= maxBytes { return }
        let ready = store.list(status: .ready).sorted { $0.updatedAtEpochMs < $1.updatedAtEpochMs }
        for entry in ready {
            if used <= maxBytes { break }
            let size = max(entry.bytesTotal, entry.bytesDownloaded)
            files.deleteMediaFiles(mediaId: entry.mediaId)
            store.delete(entry.mediaId)
            used -= size
        }
        refreshPublished()
    }

    private func refreshPublished() {
        let all = store.all()
        entries = all
        summary = OfflineCacheSummary(
            entries: all,
            readyBytes: all.filter { $0.status == .ready }
                .reduce(0) { $0 + max($1.bytesTotal, $1.bytesDownloaded) },
            readyCount: all.filter { $0.status == .ready }.count,
            activeCount: all.filter { $0.status == .queued || $0.status == .downloading }.count
        )
    }

    // MARK: - Helpers

    public nonisolated static func guessExtension(contentType: String?, contentDisposition: String?) -> String {
        if let name = filenameFromDisposition(contentDisposition) {
            let ext = name.split(separator: ".").last.map(String.init) ?? ""
            if !ext.isEmpty, ext.count <= 8 {
                return ext.lowercased()
            }
        }
        let type = contentType?.split(separator: ";").first.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        } ?? ""
        if type.contains("matroska") || type.contains("x-matroska") { return "mkv" }
        if type.contains("mp4") || type.contains("m4v") { return "mp4" }
        if type.contains("mpeg") { return "mpg" }
        if type.contains("webm") { return "webm" }
        if type.contains("quicktime") { return "mov" }
        if type.contains("avi") || type.contains("x-msvideo") { return "avi" }
        return "bin"
    }

    private nonisolated static func filenameFromDisposition(_ header: String?) -> String? {
        guard let header, !header.isEmpty else { return nil }
        if let regex = try? NSRegularExpression(pattern: #"filename\*=UTF-8''([^;]+)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
           let range = Range(match.range(at: 1), in: header)
        {
            let raw = String(header[range])
            return raw.removingPercentEncoding ?? raw
        }
        if let regex = try? NSRegularExpression(pattern: #"filename="?([^";]+)"?"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
           let range = Range(match.range(at: 1), in: header)
        {
            return String(header[range]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private struct DownloadCancelled: Error {}
}

// MARK: - URLSession download delegate

private final class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var continuation: CheckedContinuation<OfflineDownloadManager.DownloadResultBox, Error>?
    private let onProgress: (Int64, Int64) -> Void
    private var lastProgressAt: TimeInterval = 0
    private var contentType: String?
    private var contentDisposition: String?

    init(onProgress: @escaping (Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let now = Date().timeIntervalSince1970
        guard now - lastProgressAt >= 0.4 || totalBytesWritten == totalBytesExpectedToWrite else { return }
        lastProgressAt = now
        onProgress(totalBytesWritten, totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 0)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let http = downloadTask.response as? HTTPURLResponse
        contentType = http?.value(forHTTPHeaderField: "Content-Type")
        contentDisposition = http?.value(forHTTPHeaderField: "Content-Disposition")
        let status = http?.statusCode ?? -1
        if !(200..<300).contains(status) {
            continuation?.resume(
                throwing: APIError.http(status: status, message: "Download failed HTTP \(status)")
            )
            continuation = nil
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let dest = tempDir.appendingPathComponent("lumen-dl-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
            let expected = downloadTask.countOfBytesExpectedToReceive
            continuation?.resume(
                returning: OfflineDownloadManager.DownloadResultBox(
                    tempURL: dest,
                    written: size,
                    total: expected > 0 ? expected : size,
                    contentType: contentType,
                    contentDisposition: contentDisposition
                )
            )
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension OfflineDownloadManager {
    /// Box so the private delegate can construct a result without nesting types awkwardly.
    struct DownloadResultBox: Sendable {
        var tempURL: URL
        var written: Int64
        var total: Int64
        var contentType: String?
        var contentDisposition: String?
    }
}
