import Foundation

/// In-memory mock for unit tests.
public final class MockLumenMediaAPI: LumenMediaServing, @unchecked Sendable {
    public var serverInfoResult: Result<ServerInfo, Error> = .success(ServerInfo(setupCompleted: true))
    public var loginResult: Result<TokenResponse, Error>?
    public var setupCalled = false
    public var homeResult: Result<HomeResponse, Error> = .success(HomeResponse())
    public var librariesResult: Result<[LibraryDto], Error> = .success([])
    public var libraryItemsResult: Result<PagedResult<MediaItemSummary>, Error> = .success(PagedResult())
    public var itemDetailResult: Result<ItemDetail, Error>?
    public var seasonsResult: [Season] = []
    public var episodesResult: [EpisodeSummary] = []
    public var searchResult = SearchResponse()
    public var historyResult = PagedResult<HistoryEntry>()
    public var playbackDecisionResult: Result<PlaybackDecisionResponse, Error>?
    public var playbackDecisionCalls: [PlaybackDecisionRequest] = []
    public var putProgressCalls: [(String, ProgressRequest)] = []
    public var stopSessionCalls: [String] = []
    public var setQualityCalls: [(String, SetQualityRequest)] = []
    public var lastLibraryQuery: (sort: String, order: String, q: String?)?

    public init() {}

    public func serverInfo() async throws -> ServerInfo { try serverInfoResult.get() }
    public func setup(_ body: SetupRequest) async throws -> SetupResponse {
        setupCalled = true
        return SetupResponse(serverName: body.serverName)
    }
    public func login(username: String, password: String, deviceId: String?, deviceName: String?) async throws -> TokenResponse {
        if let loginResult { return try loginResult.get() }
        return TokenResponse(
            accessToken: "access",
            refreshToken: "refresh",
            expiresInSec: 3600,
            tokenType: "Bearer",
            user: UserDto(id: "u1", username: username, role: "Admin")
        )
    }
    public func refresh(refreshToken: String) async throws -> RefreshResponse {
        RefreshResponse(accessToken: "a2", refreshToken: "r2", expiresInSec: 3600)
    }
    public func logout() async {}
    public func me() async throws -> UserDto { UserDto(id: "u1", username: "admin", role: "Admin") }
    public func home() async throws -> HomeResponse { try homeResult.get() }
    public func libraries() async throws -> [LibraryDto] { try librariesResult.get() }
    public func createLibrary(_ body: CreateLibraryRequest) async throws -> LibraryDto {
        LibraryDto(id: "lib-new", name: body.name, type: body.type, paths: body.paths, itemCount: 0)
    }
    public func deleteLibrary(id: String) async throws {}
    public func scanLibrary(id: String) async throws -> JobDto {
        JobDto(id: "j1", type: "Scan", state: "Running", progress: 0)
    }
    public func libraryItems(
        id: String,
        page: Int,
        pageSize: Int,
        sort: String,
        order: String,
        watched: Bool?,
        genre: String?,
        year: Int?,
        q: String?
    ) async throws -> PagedResult<MediaItemSummary> {
        lastLibraryQuery = (sort, order, q)
        return try libraryItemsResult.get()
    }
    public func itemDetail(id: String) async throws -> ItemDetail {
        if let itemDetailResult { return try itemDetailResult.get() }
        return .movie(MovieDetail(id: id, title: "Test"))
    }
    public func seasons(seriesId: String) async throws -> [Season] { seasonsResult }
    public func episodes(seasonId: String) async throws -> [EpisodeSummary] { episodesResult }
    public func search(q: String, limit: Int) async throws -> SearchResponse { searchResult }
    public func history(page: Int, pageSize: Int) async throws -> PagedResult<HistoryEntry> { historyResult }
    public func clearHistory() async throws { historyResult = PagedResult() }
    public func playbackDecision(_ body: PlaybackDecisionRequest) async throws -> PlaybackDecisionResponse {
        playbackDecisionCalls.append(body)
        if let playbackDecisionResult { return try playbackDecisionResult.get() }
        return PlaybackDecisionResponse(
            sessionId: "sess-1",
            method: "DirectPlay",
            streamUrl: "/api/v1/stream/file",
            selectedQualityId: "auto",
            availableQualities: [
                QualityOption(id: "auto", label: "Auto", adaptive: true),
                QualityOption(id: "1080p", label: "1080p", height: 1080),
            ]
        )
    }
    public func setQuality(sessionId: String, body: SetQualityRequest) async throws -> PlaybackDecisionResponse {
        setQualityCalls.append((sessionId, body))
        return PlaybackDecisionResponse(
            sessionId: sessionId,
            method: "Transcode",
            mode: body.mode,
            streamUrl: "/api/v1/stream/\(sessionId)/index.m3u8",
            selectedQualityId: body.qualityId
        )
    }
    public func seekSession(sessionId: String, positionMs: Int64) async throws -> PlaybackDecisionResponse {
        PlaybackDecisionResponse(
            sessionId: sessionId,
            method: "Transcode",
            streamUrl: "/api/v1/stream/\(sessionId)/index.m3u8",
            startPositionMs: positionMs,
            selectedQualityId: "1080p"
        )
    }
    public func pingSession(sessionId: String) async {}
    public func stopSession(sessionId: String) async { stopSessionCalls.append(sessionId) }
    public func putProgress(itemId: String, body: ProgressRequest) async throws -> ProgressResponse {
        putProgressCalls.append((itemId, body))
        return ProgressResponse(itemId: itemId, positionMs: body.positionMs, watched: body.watched ?? false)
    }
    public func getProgress(itemId: String) async throws -> ProgressResponse {
        ProgressResponse(itemId: itemId, positionMs: 0, watched: false)
    }
    public func serverSettings() async throws -> ServerSettingsDto { ServerSettingsDto(serverName: "Lumen") }
    public func putServerSettings(_ body: ServerSettingsDto) async throws -> ServerSettingsDto { body }
    public func jobs(page: Int, pageSize: Int) async throws -> [JobDto] { [] }
}
