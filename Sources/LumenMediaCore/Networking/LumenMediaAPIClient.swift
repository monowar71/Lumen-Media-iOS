import Foundation

public enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case http(status: Int, message: String?)
    case decoding(String)
    case unauthorized
    case emptyBody

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .http(_, let message): return message ?? "Request failed"
        case .decoding(let detail): return "Could not parse response: \(detail)"
        case .unauthorized: return "Session expired"
        case .emptyBody: return "Empty response"
        }
    }
}

public extension Error {
    func lumenUserMessage(_ fallback: String) -> String {
        if let api = self as? APIError {
            return api.errorDescription ?? fallback
        }
        return (self as? LocalizedError)?.errorDescription ?? fallback
    }
}

/// Protocol boundary for ViewModels — mockable in unit tests.
public protocol LumenMediaServing: AnyObject, Sendable {
    func serverInfo() async throws -> ServerInfo
    func setup(_ body: SetupRequest) async throws -> SetupResponse
    func login(username: String, password: String, deviceId: String?, deviceName: String?) async throws -> TokenResponse
    func refresh(refreshToken: String) async throws -> RefreshResponse
    func logout() async
    func me() async throws -> UserDto
    func home() async throws -> HomeResponse
    func libraries() async throws -> [LibraryDto]
    func createLibrary(_ body: CreateLibraryRequest) async throws -> LibraryDto
    func deleteLibrary(id: String) async throws
    func scanLibrary(id: String) async throws -> JobDto
    func libraryItems(
        id: String,
        page: Int,
        pageSize: Int,
        sort: String,
        order: String,
        watched: Bool?,
        genre: String?,
        year: Int?,
        q: String?
    ) async throws -> PagedResult<MediaItemSummary>
    func itemDetail(id: String) async throws -> ItemDetail
    func seasons(seriesId: String) async throws -> [Season]
    func episodes(seasonId: String) async throws -> [EpisodeSummary]
    func search(q: String, limit: Int) async throws -> SearchResponse
    func history(page: Int, pageSize: Int) async throws -> PagedResult<HistoryEntry>
    func clearHistory() async throws
    func playbackDecision(_ body: PlaybackDecisionRequest) async throws -> PlaybackDecisionResponse
    func setQuality(sessionId: String, body: SetQualityRequest) async throws -> PlaybackDecisionResponse
    func seekSession(sessionId: String, positionMs: Int64) async throws -> PlaybackDecisionResponse
    func pingSession(sessionId: String) async
    func stopSession(sessionId: String) async
    func putProgress(itemId: String, body: ProgressRequest) async throws -> ProgressResponse
    func getProgress(itemId: String) async throws -> ProgressResponse
    func serverSettings() async throws -> ServerSettingsDto
    func putServerSettings(_ body: ServerSettingsDto) async throws -> ServerSettingsDto
    func jobs(page: Int, pageSize: Int) async throws -> [JobDto]
}

public final class LumenMediaAPIClient: LumenMediaServing, @unchecked Sendable {
    public let sessionStore: SessionStore
    public let settingsStore: SettingsStore
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let refreshLock = NSLock()
    private var refreshTask: Task<RefreshResponse, Error>?

    public init(
        sessionStore: SessionStore,
        settingsStore: SettingsStore,
        session: URLSession = .shared
    ) {
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Endpoints

    public func serverInfo() async throws -> ServerInfo {
        try await request("GET", path: "/api/v1/server/info", authorized: false)
    }

    public func setup(_ body: SetupRequest) async throws -> SetupResponse {
        try await request("POST", path: "/api/v1/setup", body: body, authorized: false)
    }

    public func login(
        username: String,
        password: String,
        deviceId: String?,
        deviceName: String?
    ) async throws -> TokenResponse {
        try await request(
            "POST",
            path: "/api/v1/auth/login",
            body: LoginRequest(
                username: username,
                password: password,
                deviceId: deviceId,
                deviceName: deviceName
            ),
            authorized: false
        )
    }

    public func refresh(refreshToken: String) async throws -> RefreshResponse {
        try await request(
            "POST",
            path: "/api/v1/auth/refresh",
            body: RefreshRequest(refreshToken: refreshToken),
            authorized: false
        )
    }

    public func logout() async {
        _ = try? await requestEmpty("POST", path: "/api/v1/auth/logout", authorized: true)
    }

    public func me() async throws -> UserDto {
        try await request("GET", path: "/api/v1/auth/me")
    }

    public func home() async throws -> HomeResponse {
        try await request("GET", path: "/api/v1/home")
    }

    public func libraries() async throws -> [LibraryDto] {
        try await request("GET", path: "/api/v1/libraries")
    }

    public func createLibrary(_ body: CreateLibraryRequest) async throws -> LibraryDto {
        try await request("POST", path: "/api/v1/libraries", body: body)
    }

    public func deleteLibrary(id: String) async throws {
        try await requestEmpty("DELETE", path: "/api/v1/libraries/\(id)")
    }

    public func scanLibrary(id: String) async throws -> JobDto {
        try await request("POST", path: "/api/v1/libraries/\(id)/scan")
    }

    public func libraryItems(
        id: String,
        page: Int,
        pageSize: Int = 40,
        sort: String = "added",
        order: String = "desc",
        watched: Bool? = nil,
        genre: String? = nil,
        year: Int? = nil,
        q: String? = nil
    ) async throws -> PagedResult<MediaItemSummary> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "order", value: order),
        ]
        if let watched { query.append(URLQueryItem(name: "watched", value: watched ? "true" : "false")) }
        if let genre, !genre.isEmpty { query.append(URLQueryItem(name: "genre", value: genre)) }
        if let year { query.append(URLQueryItem(name: "year", value: String(year))) }
        if let q, !q.isEmpty { query.append(URLQueryItem(name: "q", value: q)) }
        return try await request("GET", path: "/api/v1/libraries/\(id)/items", query: query)
    }

    public func itemDetail(id: String) async throws -> ItemDetail {
        let data = try await requestData("GET", path: "/api/v1/items/\(id)")
        let peek = try decoder.decode(KindPeek.self, from: data)
        if peek.kind == "Series" {
            return .series(try decoder.decode(SeriesDetail.self, from: data))
        }
        return .movie(try decoder.decode(MovieDetail.self, from: data))
    }

    public func seasons(seriesId: String) async throws -> [Season] {
        let page: PagedResult<Season> = try await request("GET", path: "/api/v1/series/\(seriesId)/seasons")
        return page.items
    }

    public func episodes(seasonId: String) async throws -> [EpisodeSummary] {
        let page: PagedResult<EpisodeSummary> = try await request("GET", path: "/api/v1/seasons/\(seasonId)/episodes")
        return page.items
    }

    public func search(q: String, limit: Int = 20) async throws -> SearchResponse {
        try await request(
            "GET",
            path: "/api/v1/search",
            query: [
                URLQueryItem(name: "q", value: q),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        )
    }

    public func history(page: Int = 1, pageSize: Int = 40) async throws -> PagedResult<HistoryEntry> {
        try await request(
            "GET",
            path: "/api/v1/history",
            query: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "pageSize", value: String(pageSize)),
            ]
        )
    }

    public func clearHistory() async throws {
        try await requestEmpty("DELETE", path: "/api/v1/history")
    }

    public func playbackDecision(_ body: PlaybackDecisionRequest) async throws -> PlaybackDecisionResponse {
        try await request("POST", path: "/api/v1/playback/decision", body: body)
    }

    public func setQuality(sessionId: String, body: SetQualityRequest) async throws -> PlaybackDecisionResponse {
        try await request("POST", path: "/api/v1/playback/\(sessionId)/set-quality", body: body)
    }

    public func seekSession(sessionId: String, positionMs: Int64) async throws -> PlaybackDecisionResponse {
        try await request(
            "POST",
            path: "/api/v1/playback/\(sessionId)/seek",
            body: ["positionMs": positionMs]
        )
    }

    public func pingSession(sessionId: String) async {
        _ = try? await requestEmpty("POST", path: "/api/v1/playback/\(sessionId)/ping")
    }

    public func stopSession(sessionId: String) async {
        _ = try? await requestEmpty("POST", path: "/api/v1/playback/\(sessionId)/stop")
    }

    public func putProgress(itemId: String, body: ProgressRequest) async throws -> ProgressResponse {
        try await request("PUT", path: "/api/v1/progress/\(itemId)", body: body)
    }

    public func getProgress(itemId: String) async throws -> ProgressResponse {
        try await request("GET", path: "/api/v1/progress/\(itemId)")
    }

    public func serverSettings() async throws -> ServerSettingsDto {
        try await request("GET", path: "/api/v1/settings")
    }

    public func putServerSettings(_ body: ServerSettingsDto) async throws -> ServerSettingsDto {
        try await request("PUT", path: "/api/v1/settings", body: body)
    }

    public func jobs(page: Int = 1, pageSize: Int = 50) async throws -> [JobDto] {
        let result: PagedResult<JobDto> = try await request(
            "GET",
            path: "/api/v1/jobs",
            query: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "pageSize", value: String(pageSize)),
            ]
        )
        return result.items
    }

    // MARK: - HTTP

    private struct KindPeek: Decodable {
        let kind: String?
    }

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        authorized: Bool = true,
        allowRetry: Bool = true
    ) async throws -> T {
        let data = try await requestData(
            method,
            path: path,
            query: query,
            body: body,
            authorized: authorized,
            allowRetry: allowRetry
        )
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func requestEmpty(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        authorized: Bool = true
    ) async throws {
        _ = try await requestData(method, path: path, query: query, body: body, authorized: authorized)
    }

    private func requestData(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        authorized: Bool = true,
        allowRetry: Bool = true
    ) async throws -> Data {
        var components = URLComponents(string: UrlUtils.normalizeBaseUrl(settingsStore.currentSettings.baseUrl) + path)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized, let token = sessionStore.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(status: -1, message: "Invalid response")
        }

        if http.statusCode == 401, authorized, allowRetry {
            try await refreshTokensIfNeeded()
            return try await requestData(
                method,
                path: path,
                query: query,
                body: body,
                authorized: authorized,
                allowRetry: false
            )
        }

        if (200..<300).contains(http.statusCode) {
            if data.isEmpty {
                // Encode empty object so Decodable voids / optional empties can work via callers of requestEmpty.
                return Data("{}".utf8)
            }
            return data
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        let message = (try? decoder.decode(ProblemDetails.self, from: data))?.detail
            ?? String(data: data, encoding: .utf8)
        throw APIError.http(status: http.statusCode, message: message)
    }

    private func refreshTokensIfNeeded() async throws {
        let existing: Task<RefreshResponse, Error>? = {
            refreshLock.lock()
            defer { refreshLock.unlock() }
            return refreshTask
        }()

        if let existing {
            _ = try await existing.value
            return
        }

        guard let refresh = sessionStore.refreshToken, !refresh.isEmpty else {
            sessionStore.clearSession()
            throw APIError.unauthorized
        }

        let task = Task {
            try await self.refresh(refreshToken: refresh)
        }
        refreshLock.lock()
        refreshTask = task
        refreshLock.unlock()

        defer {
            refreshLock.lock()
            refreshTask = nil
            refreshLock.unlock()
        }

        do {
            let tokens = try await task.value
            sessionStore.updateTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
        } catch {
            sessionStore.clearSession()
            throw APIError.unauthorized
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ value: any Encodable) {
        encodeFunc = { encoder in try value.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
