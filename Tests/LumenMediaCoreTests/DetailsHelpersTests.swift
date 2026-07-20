import XCTest
@testable import LumenMediaCore

final class DetailsHelpersTests: XCTestCase {
    func testIsSeriesWatched_requiresZeroUnwatched() {
        let watched = SeriesDetail(
            id: "s1",
            title: "Show",
            seasonCount: 1,
            episodeCount: 3,
            userData: UserData(unwatchedEpisodeCount: 0)
        )
        let unwatched = SeriesDetail(
            id: "s1",
            title: "Show",
            seasonCount: 1,
            episodeCount: 3,
            userData: UserData(unwatchedEpisodeCount: 2)
        )
        let empty = SeriesDetail(
            id: "s1",
            title: "Show",
            episodeCount: 0,
            userData: UserData(unwatchedEpisodeCount: 0)
        )
        XCTAssertTrue(DetailsViewModel.isSeriesWatched(watched))
        XCTAssertFalse(DetailsViewModel.isSeriesWatched(unwatched))
        XCTAssertFalse(DetailsViewModel.isSeriesWatched(empty))
    }

    func testIsSeriesWatched_defaultsUnwatchedCountToEpisodeCount() {
        let series = SeriesDetail(
            id: "s1",
            title: "Show",
            episodeCount: 5,
            userData: UserData()
        )
        XCTAssertFalse(DetailsViewModel.isSeriesWatched(series))
    }

    func testIsSeasonWatched_requiresAllEpisodesWatched() {
        let mixed = [
            EpisodeSummary(
                id: "e1",
                seasonNumber: 1,
                episodeNumber: 1,
                title: "One",
                userData: UserData(watched: true)
            ),
            EpisodeSummary(
                id: "e2",
                seasonNumber: 1,
                episodeNumber: 2,
                title: "Two",
                userData: UserData(watched: false)
            ),
        ]
        XCTAssertFalse(DetailsViewModel.isSeasonWatched(mixed))
        XCTAssertFalse(DetailsViewModel.isSeasonWatched([]))

        let allWatched = mixed.map { ep -> EpisodeSummary in
            var copy = ep
            copy.userData.watched = true
            return copy
        }
        XCTAssertTrue(DetailsViewModel.isSeasonWatched(allWatched))
    }
}
