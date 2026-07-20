import Foundation

// MARK: - Common

public struct ProblemDetails: Codable, Sendable, Equatable {
    public var title: String?
    public var detail: String?
    public var status: Int?
    public var errors: [String: [String]]?
}

public struct PagedResult<T: Codable & Sendable>: Codable, Sendable {
    public var items: [T]
    public var page: Int
    public var pageSize: Int
    public var total: Int
    public var totalPages: Int
    public var nextCursor: String?

    public init(
        items: [T] = [],
        page: Int = 1,
        pageSize: Int = 50,
        total: Int = 0,
        totalPages: Int = 0,
        nextCursor: String? = nil
    ) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.total = total
        self.totalPages = totalPages
        self.nextCursor = nextCursor
    }
}

// MARK: - Auth / Server

public struct ServerInfo: Codable, Sendable, Equatable {
    public var setupCompleted: Bool
    public var serverName: String?
    public var version: String?

    public init(setupCompleted: Bool = false, serverName: String? = nil, version: String? = nil) {
        self.setupCompleted = setupCompleted
        self.serverName = serverName
        self.version = version
    }
}

public struct SetupRequest: Codable, Sendable {
    public var username: String
    public var password: String
    public var serverName: String

    public init(username: String, password: String, serverName: String = "LumenMedia") {
        self.username = username
        self.password = password
        self.serverName = serverName
    }
}

public struct SetupResponse: Codable, Sendable {
    public var userId: String?
    public var role: String?
    public var serverName: String?
}

public struct LoginRequest: Codable, Sendable {
    public var username: String
    public var password: String
    public var deviceId: String?
    public var deviceName: String?

    public init(username: String, password: String, deviceId: String? = nil, deviceName: String? = nil) {
        self.username = username
        self.password = password
        self.deviceId = deviceId
        self.deviceName = deviceName
    }
}

public struct UserDto: Codable, Sendable, Equatable {
    public var id: String
    public var username: String
    public var role: String
    public var allowTranscoding: Bool?
    public var maxBitrateKbpsRemote: Int?
    public var createdAt: String?

    public init(
        id: String,
        username: String,
        role: String = "User",
        allowTranscoding: Bool? = true,
        maxBitrateKbpsRemote: Int? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.username = username
        self.role = role
        self.allowTranscoding = allowTranscoding
        self.maxBitrateKbpsRemote = maxBitrateKbpsRemote
        self.createdAt = createdAt
    }

    public var isAdmin: Bool { role.caseInsensitiveCompare("Admin") == .orderedSame }
}

public struct TokenResponse: Codable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresInSec: Int64?
    public var tokenType: String?
    public var user: UserDto?

    public init(
        accessToken: String,
        refreshToken: String,
        expiresInSec: Int64? = nil,
        tokenType: String? = nil,
        user: UserDto? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresInSec = expiresInSec
        self.tokenType = tokenType
        self.user = user
    }
}

public struct RefreshRequest: Codable, Sendable {
    public var refreshToken: String
    public init(refreshToken: String) { self.refreshToken = refreshToken }
}

public struct RefreshResponse: Codable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresInSec: Int64?
}

// MARK: - Library / Media

public struct ArtworkSet: Codable, Sendable, Equatable {
    public var poster: String?
    public var backdrop: String?
    public var logo: String?
    public var thumb: String?
    public var banner: String?

    public init(
        poster: String? = nil,
        backdrop: String? = nil,
        logo: String? = nil,
        thumb: String? = nil,
        banner: String? = nil
    ) {
        self.poster = poster
        self.backdrop = backdrop
        self.logo = logo
        self.thumb = thumb
        self.banner = banner
    }
}

/// Lightweight next-up payload without nested `UserData` (breaks the EpisodeSummary cycle).
public struct NextUpProgress: Codable, Sendable, Equatable {
    public var watched: Bool?
    public var playbackPositionMs: Int64?

    public init(watched: Bool? = nil, playbackPositionMs: Int64? = nil) {
        self.watched = watched
        self.playbackPositionMs = playbackPositionMs
    }
}

public struct NextUpEpisode: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: String
    public var seriesId: String
    public var seasonId: String
    public var seasonNumber: Int
    public var episodeNumber: Int
    public var title: String?
    public var overview: String?
    public var runtimeMs: Int64?
    public var artwork: ArtworkSet
    public var userData: NextUpProgress

    public init(
        id: String,
        kind: String = "Episode",
        seriesId: String = "",
        seasonId: String = "",
        seasonNumber: Int = 0,
        episodeNumber: Int = 0,
        title: String? = nil,
        overview: String? = nil,
        runtimeMs: Int64? = nil,
        artwork: ArtworkSet = ArtworkSet(),
        userData: NextUpProgress = NextUpProgress()
    ) {
        self.id = id
        self.kind = kind
        self.seriesId = seriesId
        self.seasonId = seasonId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.title = title
        self.overview = overview
        self.runtimeMs = runtimeMs
        self.artwork = artwork
        self.userData = userData
    }
}

public struct UserData: Codable, Sendable, Equatable {
    public var watched: Bool?
    public var playbackPositionMs: Int64?
    public var isFavorite: Bool?
    public var unwatchedEpisodeCount: Int?
    public var nextUp: NextUpEpisode?

    public init(
        watched: Bool? = nil,
        playbackPositionMs: Int64? = nil,
        isFavorite: Bool? = nil,
        unwatchedEpisodeCount: Int? = nil,
        nextUp: NextUpEpisode? = nil
    ) {
        self.watched = watched
        self.playbackPositionMs = playbackPositionMs
        self.isFavorite = isFavorite
        self.unwatchedEpisodeCount = unwatchedEpisodeCount
        self.nextUp = nextUp
    }
}

public struct MediaItemSummary: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var title: String
    public var originalTitle: String?
    public var year: Int?
    public var runtimeMs: Int64?
    public var communityRating: Double?
    public var officialRating: String?
    public var genres: [String]?
    public var artwork: ArtworkSet
    public var userData: UserData
    public var addedAt: String?

    public init(
        id: String,
        kind: String,
        title: String,
        originalTitle: String? = nil,
        year: Int? = nil,
        runtimeMs: Int64? = nil,
        communityRating: Double? = nil,
        officialRating: String? = nil,
        genres: [String]? = nil,
        artwork: ArtworkSet = ArtworkSet(),
        userData: UserData = UserData(),
        addedAt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.originalTitle = originalTitle
        self.year = year
        self.runtimeMs = runtimeMs
        self.communityRating = communityRating
        self.officialRating = officialRating
        self.genres = genres
        self.artwork = artwork
        self.userData = userData
        self.addedAt = addedAt
    }
}

public struct LibraryDto: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var type: String
    public var paths: [String]?
    public var itemCount: Int
    public var lastScanAt: String?

    public init(
        id: String,
        name: String,
        type: String,
        paths: [String]? = nil,
        itemCount: Int = 0,
        lastScanAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.paths = paths
        self.itemCount = itemCount
        self.lastScanAt = lastScanAt
    }
}

public struct CreateLibraryRequest: Codable, Sendable {
    public var name: String
    public var type: String
    public var paths: [String]

    public init(name: String, type: String, paths: [String]) {
        self.name = name
        self.type = type
        self.paths = paths
    }
}

public struct HomeSection: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var items: [MediaItemSummary]

    public init(id: String, title: String, items: [MediaItemSummary] = []) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct HomeResponse: Codable, Sendable {
    public var sections: [HomeSection]
    public init(sections: [HomeSection] = []) { self.sections = sections }
}

public struct SearchResponse: Codable, Sendable {
    public var movies: [MediaItemSummary]
    public var series: [MediaItemSummary]
    public var episodes: [EpisodeSummary]

    public init(
        movies: [MediaItemSummary] = [],
        series: [MediaItemSummary] = [],
        episodes: [EpisodeSummary] = []
    ) {
        self.movies = movies
        self.series = series
        self.episodes = episodes
    }
}

public struct Person: Codable, Sendable, Identifiable, Equatable {
    public var name: String
    public var role: String?
    public var type: String?
    public var order: Int?
    public var thumb: String?

    public var id: String { "\(name)-\(role ?? "")-\(order ?? 0)" }

    public init(name: String, role: String? = nil, type: String? = nil, order: Int? = nil, thumb: String? = nil) {
        self.name = name
        self.role = role
        self.type = type
        self.order = order
        self.thumb = thumb
    }
}

public struct MediaStream: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var index: Int
    public var codec: String
    public var language: String?
    public var title: String?
    public var isDefault: Bool?
    public var width: Int?
    public var height: Int?
    public var channels: Int?
    public var isExternal: Bool?
    public var format: String?
}

public struct MediaSource: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var container: String
    public var sizeBytes: Int64
    public var durationMs: Int64
    public var overallBitrateKbps: Int
    public var streams: [MediaStream]
}

public struct MovieDetail: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var title: String
    public var originalTitle: String?
    public var year: Int?
    public var overview: String?
    public var tagline: String?
    public var runtimeMs: Int64?
    public var communityRating: Double?
    public var officialRating: String?
    public var genres: [String]?
    public var people: [Person]?
    public var trailerUrl: String?
    public var artwork: ArtworkSet
    public var mediaSources: [MediaSource]
    public var userData: UserData
    public var libraryId: String
    public var addedAt: String?

    public init(
        id: String,
        kind: String = "Movie",
        title: String,
        originalTitle: String? = nil,
        year: Int? = nil,
        overview: String? = nil,
        tagline: String? = nil,
        runtimeMs: Int64? = nil,
        communityRating: Double? = nil,
        officialRating: String? = nil,
        genres: [String]? = nil,
        people: [Person]? = nil,
        trailerUrl: String? = nil,
        artwork: ArtworkSet = ArtworkSet(),
        mediaSources: [MediaSource] = [],
        userData: UserData = UserData(),
        libraryId: String = "",
        addedAt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.originalTitle = originalTitle
        self.year = year
        self.overview = overview
        self.tagline = tagline
        self.runtimeMs = runtimeMs
        self.communityRating = communityRating
        self.officialRating = officialRating
        self.genres = genres
        self.people = people
        self.trailerUrl = trailerUrl
        self.artwork = artwork
        self.mediaSources = mediaSources
        self.userData = userData
        self.libraryId = libraryId
        self.addedAt = addedAt
    }
}

public struct SeriesDetail: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var title: String
    public var year: Int?
    public var endYear: Int?
    public var status: String?
    public var overview: String?
    public var communityRating: Double?
    public var officialRating: String?
    public var genres: [String]?
    public var people: [Person]?
    public var trailerUrl: String?
    public var seasonCount: Int
    public var episodeCount: Int
    public var artwork: ArtworkSet
    public var userData: UserData
    public var libraryId: String
    public var addedAt: String?

    public init(
        id: String,
        kind: String = "Series",
        title: String,
        year: Int? = nil,
        endYear: Int? = nil,
        status: String? = nil,
        overview: String? = nil,
        communityRating: Double? = nil,
        officialRating: String? = nil,
        genres: [String]? = nil,
        people: [Person]? = nil,
        trailerUrl: String? = nil,
        seasonCount: Int = 0,
        episodeCount: Int = 0,
        artwork: ArtworkSet = ArtworkSet(),
        userData: UserData = UserData(),
        libraryId: String = "",
        addedAt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.year = year
        self.endYear = endYear
        self.status = status
        self.overview = overview
        self.communityRating = communityRating
        self.officialRating = officialRating
        self.genres = genres
        self.people = people
        self.trailerUrl = trailerUrl
        self.seasonCount = seasonCount
        self.episodeCount = episodeCount
        self.artwork = artwork
        self.userData = userData
        self.libraryId = libraryId
        self.addedAt = addedAt
    }
}

public struct Season: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var seriesId: String
    public var seasonNumber: Int
    public var name: String
    public var episodeCount: Int
    public var artwork: ArtworkSet

    public init(
        id: String,
        seriesId: String,
        seasonNumber: Int,
        name: String,
        episodeCount: Int = 0,
        artwork: ArtworkSet = ArtworkSet()
    ) {
        self.id = id
        self.seriesId = seriesId
        self.seasonNumber = seasonNumber
        self.name = name
        self.episodeCount = episodeCount
        self.artwork = artwork
    }
}

public struct EpisodeSummary: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var seriesId: String
    public var seasonId: String
    public var seasonNumber: Int
    public var episodeNumber: Int
    public var title: String?
    public var overview: String?
    public var runtimeMs: Int64?
    public var artwork: ArtworkSet
    public var userData: UserData

    public init(
        id: String,
        kind: String = "Episode",
        seriesId: String = "",
        seasonId: String = "",
        seasonNumber: Int = 0,
        episodeNumber: Int = 0,
        title: String? = nil,
        overview: String? = nil,
        runtimeMs: Int64? = nil,
        artwork: ArtworkSet = ArtworkSet(),
        userData: UserData = UserData()
    ) {
        self.id = id
        self.kind = kind
        self.seriesId = seriesId
        self.seasonId = seasonId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.title = title
        self.overview = overview
        self.runtimeMs = runtimeMs
        self.artwork = artwork
        self.userData = userData
    }
}

public struct EpisodeDetail: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var kind: String
    public var seriesId: String
    public var seasonId: String
    public var seasonNumber: Int
    public var episodeNumber: Int
    public var title: String?
    public var overview: String?
    public var runtimeMs: Int64?
    public var artwork: ArtworkSet
    public var userData: UserData
    public var mediaSources: [MediaSource]
}

// MARK: - Playback

public struct DeviceProfile: Codable, Sendable, Equatable {
    public var maxResolution: String
    public var maxBitrateKbps: Int
    public var videoCodecs: [String]
    public var audioCodecs: [String]
    public var containers: [String]
    public var subtitleFormats: [String]
    public var supportsHevc: Bool
    public var supportsHdr: Bool

    public init(
        maxResolution: String,
        maxBitrateKbps: Int,
        videoCodecs: [String],
        audioCodecs: [String],
        containers: [String],
        subtitleFormats: [String],
        supportsHevc: Bool,
        supportsHdr: Bool
    ) {
        self.maxResolution = maxResolution
        self.maxBitrateKbps = maxBitrateKbps
        self.videoCodecs = videoCodecs
        self.audioCodecs = audioCodecs
        self.containers = containers
        self.subtitleFormats = subtitleFormats
        self.supportsHevc = supportsHevc
        self.supportsHdr = supportsHdr
    }
}

public struct PlaybackDecisionRequest: Codable, Sendable {
    public var mediaId: String
    public var mediaSourceId: String?
    public var mode: String
    public var qualityId: String?
    public var audioStreamId: String?
    public var subtitleStreamId: String?
    public var resumePositionMs: Int64
    public var profile: DeviceProfile

    public init(
        mediaId: String,
        mediaSourceId: String? = nil,
        mode: String = "auto",
        qualityId: String? = nil,
        audioStreamId: String? = nil,
        subtitleStreamId: String? = nil,
        resumePositionMs: Int64 = 0,
        profile: DeviceProfile
    ) {
        self.mediaId = mediaId
        self.mediaSourceId = mediaSourceId
        self.mode = mode
        self.qualityId = qualityId
        self.audioStreamId = audioStreamId
        self.subtitleStreamId = subtitleStreamId
        self.resumePositionMs = resumePositionMs
        self.profile = profile
    }
}

public struct QualityOption: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var label: String
    public var adaptive: Bool?
    public var width: Int?
    public var height: Int?
    public var bitrateKbps: Int?

    public init(
        id: String,
        label: String,
        adaptive: Bool? = nil,
        width: Int? = nil,
        height: Int? = nil,
        bitrateKbps: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.adaptive = adaptive
        self.width = width
        self.height = height
        self.bitrateKbps = bitrateKbps
    }
}

public struct AudioStreamOption: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var language: String?
    public var codec: String?
    public var channels: Int?
    public var isDefault: Bool?

    public init(
        id: String,
        language: String? = nil,
        codec: String? = nil,
        channels: Int? = nil,
        isDefault: Bool? = nil
    ) {
        self.id = id
        self.language = language
        self.codec = codec
        self.channels = channels
        self.isDefault = isDefault
    }

    public var displayLabel: String {
        var parts: [String] = []
        if let language, !language.isEmpty { parts.append(Self.prettyLanguage(language)) }
        if let codec, !codec.isEmpty { parts.append(codec.uppercased()) }
        if let channels, channels > 0 { parts.append("\(channels)ch") }
        if parts.isEmpty { return "Audio" }
        return parts.joined(separator: " · ")
    }

    public var shortLabel: String {
        if let language, !language.isEmpty { return Self.prettyLanguage(language) }
        if let codec, !codec.isEmpty { return codec.uppercased() }
        return "Audio"
    }

    private static func prettyLanguage(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 3 else { return trimmed }
        return Locale.current.localizedString(forLanguageCode: trimmed) ?? trimmed.uppercased()
    }
}

public struct SubtitleStreamOption: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var language: String?
    public var format: String?
    public var deliveryUrl: String
}

public struct PlaybackDecisionResponse: Codable, Sendable, Equatable {
    public var sessionId: String
    public var method: String
    public var mode: String
    public var streamUrl: String
    public var container: String
    public var startPositionMs: Int64?
    public var durationMs: Int64?
    public var selectedQualityId: String
    public var availableQualities: [QualityOption]
    public var audioStreams: [AudioStreamOption]
    public var subtitleStreams: [SubtitleStreamOption]
    public var expiresAt: String?
    public var reason: String?

    public init(
        sessionId: String,
        method: String,
        mode: String = "auto",
        streamUrl: String,
        container: String = "",
        startPositionMs: Int64? = nil,
        durationMs: Int64? = nil,
        selectedQualityId: String = "auto",
        availableQualities: [QualityOption] = [],
        audioStreams: [AudioStreamOption] = [],
        subtitleStreams: [SubtitleStreamOption] = [],
        expiresAt: String? = nil,
        reason: String? = nil
    ) {
        self.sessionId = sessionId
        self.method = method
        self.mode = mode
        self.streamUrl = streamUrl
        self.container = container
        self.startPositionMs = startPositionMs
        self.durationMs = durationMs
        self.selectedQualityId = selectedQualityId
        self.availableQualities = availableQualities
        self.audioStreams = audioStreams
        self.subtitleStreams = subtitleStreams
        self.expiresAt = expiresAt
        self.reason = reason
    }
}

public struct SetQualityRequest: Codable, Sendable {
    public var qualityId: String
    public var mode: String
    public var resumePositionMs: Int64

    public init(qualityId: String, mode: String, resumePositionMs: Int64) {
        self.qualityId = qualityId
        self.mode = mode
        self.resumePositionMs = resumePositionMs
    }
}

public struct ProgressRequest: Codable, Sendable {
    public var positionMs: Int64
    public var durationMs: Int64?
    public var sessionId: String?
    public var state: String?
    public var watched: Bool?

    public init(
        positionMs: Int64 = 0,
        durationMs: Int64? = nil,
        sessionId: String? = nil,
        state: String? = nil,
        watched: Bool? = nil
    ) {
        self.positionMs = positionMs
        self.durationMs = durationMs
        self.sessionId = sessionId
        self.state = state
        self.watched = watched
    }
}

public struct ProgressResponse: Codable, Sendable {
    public var itemId: String
    public var positionMs: Int64
    public var watched: Bool
    public var updatedAt: String?
}

public struct HistoryEntry: Codable, Sendable, Equatable {
    public var entryId: String?
    public var itemId: String?
    public var kind: String?
    public var title: String?
    public var seriesTitle: String?
    public var seasonNumber: Int?
    public var episodeNumber: Int?
    public var artwork: ArtworkSet?
    public var watched: Bool?
    public var positionMs: Int64?
    public var durationMs: Int64?
    public var updatedAt: String?

    public var id: String {
        entryId ?? itemId ?? "\(title ?? "")-\(updatedAt ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case entryId = "id"
        case itemId, kind, title, seriesTitle, seasonNumber, episodeNumber
        case artwork, watched, positionMs, durationMs, updatedAt
    }
}

public struct JobDto: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var type: String
    public var state: String
    public var progress: Double
    public var message: String?
    public var libraryId: String?
    public var error: String?
}

public struct ServerSettingsDto: Codable, Sendable, Equatable {
    public var serverName: String?
    public var metadataLanguage: String?
}

public enum ItemDetail: Sendable, Equatable {
    case movie(MovieDetail)
    case series(SeriesDetail)

    public var id: String {
        switch self {
        case .movie(let m): return m.id
        case .series(let s): return s.id
        }
    }
}
