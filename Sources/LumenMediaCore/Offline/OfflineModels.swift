import Foundation

public enum CachedMediaStatus: String, Codable, Sendable, Equatable {
    case queued
    case downloading
    case ready
    case failed
}

public struct OfflineEnqueueRequest: Sendable, Equatable {
    public var mediaId: String
    public var kind: String
    public var seriesId: String
    public var seasonId: String
    public var title: String
    public var seasonNumber: Int
    public var episodeNumber: Int
    public var episodeTitle: String?

    public init(
        mediaId: String,
        kind: String = "Episode",
        seriesId: String = "",
        seasonId: String = "",
        title: String,
        seasonNumber: Int = 0,
        episodeNumber: Int = 0,
        episodeTitle: String? = nil
    ) {
        self.mediaId = mediaId
        self.kind = kind
        self.seriesId = seriesId
        self.seasonId = seasonId
        self.title = title
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
    }

    public static func episode(
        from episode: EpisodeSummary,
        seriesId: String,
        seriesTitle: String,
        seasonId: String
    ) -> OfflineEnqueueRequest {
        OfflineEnqueueRequest(
            mediaId: episode.id,
            kind: "Episode",
            seriesId: seriesId.ifBlank(episode.seriesId),
            seasonId: seasonId.ifBlank(episode.seasonId),
            title: seriesTitle,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            episodeTitle: episode.title
        )
    }

    public static func movie(from movie: MovieDetail) -> OfflineEnqueueRequest {
        OfflineEnqueueRequest(
            mediaId: movie.id,
            kind: "Movie",
            title: movie.title
        )
    }
}

public struct OfflineCachedItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String { mediaId }
    public var mediaId: String
    public var kind: String
    public var seriesId: String
    public var seasonId: String
    public var title: String
    public var seasonNumber: Int
    public var episodeNumber: Int
    public var episodeTitle: String?
    public var status: CachedMediaStatus
    public var bytesDownloaded: Int64
    public var bytesTotal: Int64
    public var localPath: String?
    public var container: String?
    public var errorMessage: String?
    public var updatedAtEpochMs: Int64
    public var createdAtEpochMs: Int64

    public init(
        mediaId: String,
        kind: String = "Episode",
        seriesId: String = "",
        seasonId: String = "",
        title: String,
        seasonNumber: Int = 0,
        episodeNumber: Int = 0,
        episodeTitle: String? = nil,
        status: CachedMediaStatus = .queued,
        bytesDownloaded: Int64 = 0,
        bytesTotal: Int64 = 0,
        localPath: String? = nil,
        container: String? = nil,
        errorMessage: String? = nil,
        updatedAtEpochMs: Int64 = 0,
        createdAtEpochMs: Int64 = 0
    ) {
        self.mediaId = mediaId
        self.kind = kind
        self.seriesId = seriesId
        self.seasonId = seasonId
        self.title = title
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
        self.status = status
        self.bytesDownloaded = bytesDownloaded
        self.bytesTotal = bytesTotal
        self.localPath = localPath
        self.container = container
        self.errorMessage = errorMessage
        self.updatedAtEpochMs = updatedAtEpochMs
        self.createdAtEpochMs = createdAtEpochMs
    }

    public var progress: Double {
        switch status {
        case .ready: return 1
        case .queued, .failed: return 0
        case .downloading:
            guard bytesTotal > 0 else { return 0 }
            return min(1, max(0, Double(bytesDownloaded) / Double(bytesTotal)))
        }
    }

    public var displayTitle: String {
        if kind == "Movie" || seasonNumber == 0 {
            return title
        }
        var result = "\(title) · S\(seasonNumber)E\(episodeNumber)"
        if let episodeTitle, !episodeTitle.isEmpty {
            result += " · \(episodeTitle)"
        }
        return result
    }
}

public struct OfflineCacheSummary: Equatable, Sendable {
    public var entries: [OfflineCachedItem]
    public var readyBytes: Int64
    public var readyCount: Int
    public var activeCount: Int

    public init(
        entries: [OfflineCachedItem] = [],
        readyBytes: Int64 = 0,
        readyCount: Int = 0,
        activeCount: Int = 0
    ) {
        self.entries = entries
        self.readyBytes = readyBytes
        self.readyCount = readyCount
        self.activeCount = activeCount
    }
}

private extension String {
    func ifBlank(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
