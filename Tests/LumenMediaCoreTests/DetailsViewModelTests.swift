import XCTest
@testable import LumenMediaCore

@MainActor
final class DetailsViewModelTests: XCTestCase {
    private var api: MockLumenMediaAPI!
    private var settingsStore: SettingsStore!
    private var suiteName: String!

    override func setUp() async throws {
        api = MockLumenMediaAPI()
        suiteName = "test.lumen.details.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(defaults: defaults)
        settingsStore.setBaseUrl("http://server")
    }

    override func tearDown() async throws {
        if let suiteName {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        api = nil
        settingsStore = nil
        suiteName = nil
    }

    func testMovieLoad() async {
        api.itemDetailResult = .success(
            .movie(
                MovieDetail(
                    id: "m1",
                    title: "Matrix",
                    overview: "Neo",
                    userData: UserData(watched: false, playbackPositionMs: 1_000)
                )
            )
        )

        let vm = DetailsViewModel(itemId: "m1", api: api, settingsStore: settingsStore)
        await vm.refresh()

        XCTAssertFalse(vm.state.loading)
        XCTAssertEqual(vm.state.movie?.title, "Matrix")
        XCTAssertNil(vm.state.series)
        XCTAssertTrue(vm.state.seasons.isEmpty)
        XCTAssertEqual(vm.state.baseUrl, "http://server")
    }

    func testSeriesLoad_withSeasonsAndEpisodes() async {
        api.itemDetailResult = .success(
            .series(
                SeriesDetail(
                    id: "s1",
                    title: "Show",
                    seasonCount: 1,
                    episodeCount: 2,
                    userData: UserData(unwatchedEpisodeCount: 2)
                )
            )
        )
        api.seasonsResult = [
            Season(id: "sea1", seriesId: "s1", seasonNumber: 1, name: "Season 1", episodeCount: 2),
        ]
        api.episodesResult = [
            EpisodeSummary(
                id: "e1",
                seriesId: "s1",
                seasonId: "sea1",
                seasonNumber: 1,
                episodeNumber: 1,
                title: "Pilot",
                userData: UserData(watched: false)
            ),
            EpisodeSummary(
                id: "e2",
                seriesId: "s1",
                seasonId: "sea1",
                seasonNumber: 1,
                episodeNumber: 2,
                title: "Next",
                userData: UserData(watched: false)
            ),
        ]

        let vm = DetailsViewModel(itemId: "s1", api: api, settingsStore: settingsStore)
        await vm.refresh()

        XCTAssertFalse(vm.state.loading)
        XCTAssertEqual(vm.state.series?.title, "Show")
        XCTAssertNil(vm.state.movie)
        XCTAssertEqual(vm.state.seasons.count, 1)
        XCTAssertEqual(vm.state.selectedSeasonId, "sea1")
        XCTAssertEqual(vm.state.episodes.map(\.id), ["e1", "e2"])
    }

    func testToggleMovieWatched_marksViaProgressApi() async {
        api.itemDetailResult = .success(
            .movie(
                MovieDetail(
                    id: "m1",
                    title: "Matrix",
                    userData: UserData(watched: false, playbackPositionMs: 1_000)
                )
            )
        )

        let vm = DetailsViewModel(itemId: "m1", api: api, settingsStore: settingsStore)
        await vm.refresh()
        await vm.toggleMovieWatched()

        XCTAssertEqual(api.putProgressCalls.count, 1)
        XCTAssertEqual(api.putProgressCalls[0].0, "m1")
        XCTAssertEqual(api.putProgressCalls[0].1.watched, true)
        XCTAssertEqual(vm.state.movie?.userData.watched, true)
        XCTAssertEqual(vm.state.movie?.userData.playbackPositionMs, 0)
        XCTAssertFalse(vm.state.markingWatched)
    }
}
