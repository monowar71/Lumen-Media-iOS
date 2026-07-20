import XCTest
@testable import LumenMediaCore

@MainActor
final class LibraryViewModelTests: XCTestCase {
    private var api: MockLumenMediaAPI!
    private var settingsStore: SettingsStore!
    private var suiteName: String!

    override func setUp() async throws {
        api = MockLumenMediaAPI()
        suiteName = "test.lumen.library.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(defaults: defaults)
        settingsStore.setBaseUrl("http://server")

        api.librariesResult = .success([
            LibraryDto(id: "lib1", name: "Movies", type: "Movies", itemCount: 2),
        ])
    }

    override func tearDown() async throws {
        if let suiteName {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        api = nil
        settingsStore = nil
        suiteName = nil
    }

    func testLoad_populatesItemsAndLibrary() async {
        api.libraryItemsResult = .success(
            PagedResult(
                items: [
                    MediaItemSummary(id: "m1", kind: "Movie", title: "One"),
                    MediaItemSummary(id: "m2", kind: "Movie", title: "Two"),
                ],
                page: 1,
                pageSize: 40,
                total: 2,
                totalPages: 1
            )
        )

        let vm = LibraryViewModel(libraryId: "lib1", api: api, settingsStore: settingsStore)
        await vm.refresh()

        XCTAssertFalse(vm.state.loading)
        XCTAssertEqual(vm.state.items.map(\.id), ["m1", "m2"])
        XCTAssertEqual(vm.state.library?.id, "lib1")
        XCTAssertEqual(vm.state.libraries.count, 1)
        XCTAssertFalse(vm.state.hasMore)
        XCTAssertEqual(vm.state.baseUrl, "http://server")
    }

    func testSortChange_persistsAndReloadsWithNewSortParams() async {
        api.libraryItemsResult = .success(
            PagedResult(
                items: [MediaItemSummary(id: "m1", kind: "Movie", title: "A")],
                page: 1,
                pageSize: 40,
                total: 1,
                totalPages: 1
            )
        )

        let vm = LibraryViewModel(libraryId: "lib1", api: api, settingsStore: settingsStore)
        await vm.refresh()

        api.libraryItemsResult = .success(
            PagedResult(
                items: [
                    MediaItemSummary(id: "m1", kind: "Movie", title: "A"),
                    MediaItemSummary(id: "m2", kind: "Movie", title: "B"),
                ],
                page: 1,
                pageSize: 40,
                total: 2,
                totalPages: 1
            )
        )

        vm.onSortChange(.title)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(vm.state.sort, .title)
        XCTAssertEqual(settingsStore.currentSettings.librarySort, .title)
        XCTAssertEqual(api.lastLibraryQuery?.sort, "title")
        XCTAssertEqual(api.lastLibraryQuery?.order, "asc")
        XCTAssertEqual(vm.state.items.count, 2)
    }
}
