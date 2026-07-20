import XCTest
@testable import LumenMediaCore

@MainActor
final class SearchViewModelTests: XCTestCase {
    private var api: MockLumenMediaAPI!
    private var settingsStore: SettingsStore!
    private var suiteName: String!

    override func setUp() async throws {
        api = MockLumenMediaAPI()
        suiteName = "test.lumen.search.\(UUID().uuidString)"
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

    func testDebounceThreshold_shortQueryClearsResults() async {
        api.searchResult = SearchResponse(
            movies: [MediaItemSummary(id: "m1", kind: "Movie", title: "Matrix")]
        )

        let vm = SearchViewModel(api: api, settingsStore: settingsStore)
        vm.onQueryChange("ma")
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(vm.state.movies.count, 1)

        vm.onQueryChange("m")
        XCTAssertTrue(vm.state.movies.isEmpty)
        XCTAssertTrue(vm.state.series.isEmpty)
        XCTAssertTrue(vm.state.episodes.isEmpty)
        XCTAssertFalse(vm.state.loading)
        XCTAssertNil(vm.state.error)
    }

    func testSearch_loadsResults_whenQueryLongerThanOne() async {
        api.searchResult = SearchResponse(
            movies: [MediaItemSummary(id: "m1", kind: "Movie", title: "Matrix")],
            series: [MediaItemSummary(id: "s1", kind: "Series", title: "Mandalorian")],
            episodes: [
                EpisodeSummary(
                    id: "e1",
                    seasonNumber: 1,
                    episodeNumber: 1,
                    title: "Pilot"
                ),
            ]
        )

        let vm = SearchViewModel(api: api, settingsStore: settingsStore)
        vm.onQueryChange("ma")
        try? await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertFalse(vm.state.loading)
        XCTAssertEqual(vm.state.movies.map(\.id), ["m1"])
        XCTAssertEqual(vm.state.series.map(\.id), ["s1"])
        XCTAssertEqual(vm.state.episodes.map(\.id), ["e1"])
        XCTAssertEqual(vm.state.baseUrl, "http://server")
        XCTAssertFalse(vm.state.isEmpty)
    }

    func testSearch_directCall_respectsThreshold() async {
        api.searchResult = SearchResponse(
            movies: [MediaItemSummary(id: "m1", kind: "Movie", title: "X")]
        )
        let vm = SearchViewModel(api: api, settingsStore: settingsStore)
        vm.onQueryChange("x")
        await vm.search()
        XCTAssertTrue(vm.state.movies.isEmpty)
    }
}
