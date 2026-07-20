import XCTest
@testable import LumenMediaCore

final class LibraryOrderingTests: XCTestCase {
    private func item(
        id: String,
        watched: Bool? = nil,
        positionMs: Int64? = nil
    ) -> MediaItemSummary {
        MediaItemSummary(
            id: id,
            kind: "Movie",
            title: id,
            userData: UserData(watched: watched, playbackPositionMs: positionMs)
        )
    }

    func testOrderItems_inProgressFirst_movesStartedUnfinishedToTop() {
        let watched = item(id: "watched", watched: true, positionMs: 100)
        let fresh = item(id: "fresh")
        let started = item(id: "started", watched: false, positionMs: 5_000)

        let ordered = LibraryViewModel.orderItems(
            [watched, fresh, started],
            inProgressFirst: true
        )
        XCTAssertEqual(ordered.map(\.id), ["started", "watched", "fresh"])
    }

    func testOrderItems_disabled_preservesOriginalOrder() {
        let items = [
            item(id: "a"),
            item(id: "b", watched: false, positionMs: 10),
            item(id: "c"),
        ]
        let ordered = LibraryViewModel.orderItems(items, inProgressFirst: false)
        XCTAssertEqual(ordered.map(\.id), ["a", "b", "c"])
    }

    func testOrderItems_watchedWithPosition_notTreatedAsInProgress() {
        let watchedProgress = item(id: "done", watched: true, positionMs: 9_000)
        let started = item(id: "started", watched: false, positionMs: 1)
        let ordered = LibraryViewModel.orderItems(
            [watchedProgress, started],
            inProgressFirst: true
        )
        XCTAssertEqual(ordered.map(\.id), ["started", "done"])
    }

    func testHasMore_usesTotalPagesWhenAvailable() {
        let more = PagedResult<MediaItemSummary>(
            items: [item(id: "1")],
            page: 1,
            pageSize: 40,
            total: 80,
            totalPages: 2
        )
        XCTAssertTrue(LibraryViewModel.hasMore(more))

        let last = PagedResult<MediaItemSummary>(
            items: [item(id: "1")],
            page: 2,
            pageSize: 40,
            total: 80,
            totalPages: 2
        )
        XCTAssertFalse(LibraryViewModel.hasMore(last))
    }

    func testHasMore_fallsBackToPageSizeHeuristic() {
        let fullPage = PagedResult<MediaItemSummary>(
            items: (0..<40).map { item(id: "\($0)") },
            page: 1,
            pageSize: 40,
            total: 0,
            totalPages: 0
        )
        XCTAssertTrue(LibraryViewModel.hasMore(fullPage))

        let shortPage = PagedResult<MediaItemSummary>(
            items: [item(id: "1")],
            page: 1,
            pageSize: 40,
            total: 0,
            totalPages: 0
        )
        XCTAssertFalse(LibraryViewModel.hasMore(shortPage))
    }
}
