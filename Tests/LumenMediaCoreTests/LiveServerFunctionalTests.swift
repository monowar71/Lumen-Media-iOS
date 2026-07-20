import XCTest
@testable import LumenMediaCore

/// Live functional checks against a running LumenMedia server.
/// Enable with: `LUMEN_LIVE_TEST=1 LUMEN_BASE_URL=... LUMEN_USER=admin LUMEN_PASS=admin123 swift test --filter LiveServer`
final class LiveServerFunctionalTests: XCTestCase {
    private var api: LumenMediaAPIClient!
    private var sessionStore: SessionStore!
    private var settingsStore: SettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["LUMEN_LIVE_TEST"] == "1",
            "Set LUMEN_LIVE_TEST=1 to run live server tests"
        )
        let base = ProcessInfo.processInfo.environment["LUMEN_BASE_URL"] ?? "http://192.168.0.2:8096"
        let defaults = UserDefaults(suiteName: "live-functional-\(UUID().uuidString)")!
        sessionStore = SessionStore()
        sessionStore.clear()
        settingsStore = SettingsStore(defaults: defaults)
        settingsStore.setBaseUrl(base)
        api = LumenMediaAPIClient(sessionStore: sessionStore, settingsStore: settingsStore)
    }

    func testFullClientPath_loginHomeLibraryDetailsPlaybackSearchHistory() async throws {
        let user = ProcessInfo.processInfo.environment["LUMEN_USER"] ?? "admin"
        let pass = ProcessInfo.processInfo.environment["LUMEN_PASS"] ?? "admin123"

        let login = try await api.login(
            username: user,
            password: pass,
            deviceId: "ios-live-test",
            deviceName: "Live Functional Test"
        )
        XCTAssertFalse(login.accessToken.isEmpty)
        let loggedInUser = try XCTUnwrap(login.user)
        sessionStore.saveSession(
            AuthSession(
                accessToken: login.accessToken,
                refreshToken: login.refreshToken,
                userId: loggedInUser.id,
                username: loggedInUser.username,
                role: loggedInUser.role
            )
        )

        let me = try await api.me()
        XCTAssertEqual(me.username, user)

        let home = try await api.home()
        XCTAssertFalse(home.sections.isEmpty)

        let libraries = try await api.libraries()
        XCTAssertFalse(libraries.isEmpty)

        guard let movies = libraries.first(where: { $0.type == "Movies" })
            ?? libraries.first
        else {
            return XCTFail("No libraries")
        }

        let page = try await api.libraryItems(id: movies.id, page: 1, pageSize: 10)
        XCTAssertFalse(page.items.isEmpty)

        let summary = try XCTUnwrap(page.items.first)
        let detail = try await api.itemDetail(id: summary.id)

        var playableId = summary.id
        switch detail {
        case .movie(let movie):
            XCTAssertFalse(movie.title.isEmpty)
            playableId = movie.id
        case .series(let series):
            XCTAssertFalse(series.title.isEmpty)
            let seasons = try await api.seasons(seriesId: series.id)
            XCTAssertFalse(seasons.isEmpty)
            let episodes = try await api.episodes(seasonId: seasons[0].id)
            XCTAssertFalse(episodes.isEmpty)
            playableId = episodes[0].id
        }

        let query = String(summary.title.prefix(3))
        let search = try await api.search(q: query, limit: 10)
        XCTAssertTrue(
            !search.movies.isEmpty || !search.series.isEmpty || !search.episodes.isEmpty,
            "search for \(query) returned nothing"
        )

        _ = try await api.history(page: 1, pageSize: 10)
        _ = try await api.serverSettings()

        let playableIdFixed = playableId
        let playerDefaults = UserDefaults(suiteName: "live-player-\(UUID().uuidString)")!
        let playerSettings = SettingsStore(defaults: playerDefaults)
        playerSettings.setBaseUrl(settingsStore.currentSettings.baseUrl)
        let player = await MainActor.run {
            PlayerSessionViewModel(itemId: playableIdFixed, api: api, settingsStore: playerSettings)
        }
        await MainActor.run { player.accessToken = login.accessToken }
        await player.start()
        let decision = await MainActor.run { player.decision }
        let error = await MainActor.run { player.error }
        let source = await MainActor.run { player.streamSource }
        XCTAssertNil(error, "playback error: \(error ?? "")")
        XCTAssertNotNil(decision)
        XCTAssertNotEqual(
            decision?.method,
            "DirectPlay",
            "AVPlayer cannot DirectPlay typical library MKV files; profile should force remux/HLS"
        )
        XCTAssertNotNil(source)
        if case .hls(let url) = source {
            XCTAssertTrue(url.contains(".m3u8") || url.contains("/stream/"), url)
        } else if case .direct(let url) = source {
            XCTAssertTrue(url.contains("download") || url.contains(".mp4"), url)
        }
        await player.stop()
    }
}
