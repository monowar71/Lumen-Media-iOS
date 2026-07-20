import XCTest
@testable import LumenMediaCore

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var api: MockLumenMediaAPI!
    private var settingsStore: SettingsStore!
    private var suiteName: String!

    override func setUp() async throws {
        api = MockLumenMediaAPI()
        suiteName = "test.lumen.home.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(defaults: defaults)
        settingsStore.setBaseUrl("http://server:8096")
    }

    override func tearDown() async throws {
        if let suiteName {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        api = nil
        settingsStore = nil
        suiteName = nil
    }

    func testRefresh_loadsSections_filteringEmpty() async {
        let movie = MediaItemSummary(id: "m1", kind: "Movie", title: "Inception")
        api.homeResult = .success(
            HomeResponse(sections: [
                HomeSection(id: "continue", title: "Continue Watching", items: [movie]),
                HomeSection(id: "empty", title: "Recently Added", items: []),
                HomeSection(id: "movies", title: "Movies", items: [
                    MediaItemSummary(id: "m2", kind: "Movie", title: "Matrix"),
                ]),
            ])
        )

        let vm = HomeViewModel(api: api, settingsStore: settingsStore)
        await vm.refresh()

        XCTAssertFalse(vm.state.loading)
        XCTAssertNil(vm.state.error)
        XCTAssertEqual(vm.state.sections.map(\.id), ["continue", "movies"])
        XCTAssertEqual(vm.state.baseUrl, "http://server:8096")
        XCTAssertEqual(vm.state.heroItem?.id, "m1")
    }

    func testRefresh_failure_setsError() async {
        api.homeResult = .failure(APIError.http(status: 500, message: "boom"))

        let vm = HomeViewModel(api: api, settingsStore: settingsStore)
        await vm.refresh()

        XCTAssertFalse(vm.state.loading)
        XCTAssertEqual(vm.state.error, "boom")
        XCTAssertTrue(vm.state.sections.isEmpty)
    }
}
