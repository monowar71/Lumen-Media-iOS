import Foundation
import Combine

public struct DetailsUiState: Equatable, Sendable {
    public var loading: Bool = true
    public var error: String?
    public var baseUrl: String = ""
    public var movie: MovieDetail?
    public var series: SeriesDetail?
    public var seasons: [Season] = []
    public var selectedSeasonId: String?
    public var episodes: [EpisodeSummary] = []
    public var markingWatched: Bool = false
    public var offlineByMediaId: [String: OfflineCachedItem] = [:]
}

@MainActor
public final class DetailsViewModel: ObservableObject {
    @Published public private(set) var state = DetailsUiState()

    private let itemId: String
    private let api: any LumenMediaServing
    private let settingsStore: SettingsStore
    private let offline: OfflineDownloadManager?
    private var cancellables = Set<AnyCancellable>()

    public init(
        itemId: String,
        api: any LumenMediaServing,
        settingsStore: SettingsStore,
        offline: OfflineDownloadManager? = nil
    ) {
        self.itemId = itemId
        self.api = api
        self.settingsStore = settingsStore
        self.offline = offline
        if let offline {
            state.offlineByMediaId = Dictionary(
                uniqueKeysWithValues: offline.entries.map { ($0.mediaId, $0) }
            )
            offline.$entries
                .receive(on: DispatchQueue.main)
                .sink { [weak self] entries in
                    self?.state.offlineByMediaId = Dictionary(
                        uniqueKeysWithValues: entries.map { ($0.mediaId, $0) }
                    )
                }
                .store(in: &cancellables)
        }
    }

    public func refresh() async {
        state.loading = true
        state.error = nil
        let baseUrl = settingsStore.currentSettings.baseUrl
        do {
            let detail = try await api.itemDetail(id: itemId)
            switch detail {
            case .movie(let movie):
                state.loading = false
                state.movie = movie
                state.series = nil
                state.seasons = []
                state.episodes = []
                state.baseUrl = baseUrl
            case .series(let series):
                let seasons = try await api.seasons(seriesId: itemId)
                let first = seasons.first
                let episodes = if let first {
                    try await api.episodes(seasonId: first.id)
                } else {
                    [EpisodeSummary]()
                }
                state.loading = false
                state.series = series
                state.movie = nil
                state.seasons = seasons
                state.selectedSeasonId = first?.id
                state.episodes = episodes
                state.baseUrl = baseUrl
            }
        } catch {
            state.loading = false
            state.error = error.lumenUserMessage("Failed to load details")
        }
    }

    public func selectSeason(_ seasonId: String) async {
        guard seasonId != state.selectedSeasonId else { return }
        state.selectedSeasonId = seasonId
        state.episodes = []
        do {
            state.episodes = try await api.episodes(seasonId: seasonId)
        } catch {
            state.error = error.lumenUserMessage("Failed to load episodes")
        }
    }

    public func toggleMovieWatched() async {
        guard let movie = state.movie else { return }
        let next = movie.userData.watched != true
        await setWatched(movie.id, watched: next) {
            var updated = movie
            updated.userData.watched = next
            if next { updated.userData.playbackPositionMs = 0 }
            state.movie = updated
        }
    }

    public func toggleSeriesWatched() async {
        guard let series = state.series else { return }
        let next = !Self.isSeriesWatched(series)
        await setWatched(series.id, watched: next) {
            applyEpisodeWatched(watched: next)
            var updated = series
            updated.userData.unwatchedEpisodeCount = next ? 0 : series.episodeCount
            state.series = updated
        }
    }

    public func toggleSeasonWatched() async {
        guard let seasonId = state.selectedSeasonId, !state.episodes.isEmpty else { return }
        let next = !Self.isSeasonWatched(state.episodes)
        await setWatched(seasonId, watched: next) {
            applyEpisodeWatched(watched: next)
            await refreshSeriesUnwatchedCount()
        }
    }

    public func toggleEpisodeWatched(_ episodeId: String) async {
        guard let episode = state.episodes.first(where: { $0.id == episodeId }) else { return }
        let next = episode.userData.watched != true
        await setWatched(episodeId, watched: next) {
            state.episodes = state.episodes.map { ep in
                guard ep.id == episodeId else { return ep }
                var copy = ep
                copy.userData.watched = next
                if next { copy.userData.playbackPositionMs = 0 }
                return copy
            }
            await refreshSeriesUnwatchedCount()
        }
    }

    public func downloadMovie() async {
        guard let movie = state.movie, let offline else { return }
        await offline.enqueue(.movie(from: movie))
    }

    public func downloadEpisode(_ episodeId: String) async {
        guard let series = state.series,
              let episode = state.episodes.first(where: { $0.id == episodeId }),
              let offline
        else { return }
        await offline.enqueue(
            .episode(
                from: episode,
                seriesId: series.id,
                seriesTitle: series.title,
                seasonId: state.selectedSeasonId ?? episode.seasonId
            )
        )
    }

    public func downloadSeason() async {
        guard let series = state.series,
              let seasonId = state.selectedSeasonId,
              let offline,
              !state.episodes.isEmpty
        else { return }
        await offline.enqueueSeason(
            seriesId: series.id,
            seriesTitle: series.title,
            seasonId: seasonId,
            episodes: state.episodes
        )
    }

    public func removeOffline(_ mediaId: String) async {
        await offline?.remove(mediaId)
    }

    public func cancelOffline(_ mediaId: String) async {
        await offline?.cancel(mediaId)
    }

    private func setWatched(_ targetId: String, watched: Bool, onSuccess: () async -> Void) async {
        guard !state.markingWatched else { return }
        state.markingWatched = true
        state.error = nil
        do {
            _ = try await api.putProgress(itemId: targetId, body: ProgressRequest(watched: watched))
            await onSuccess()
            state.markingWatched = false
        } catch {
            state.markingWatched = false
            state.error = error.lumenUserMessage("Failed to update watched status")
        }
    }

    private func applyEpisodeWatched(watched: Bool) {
        state.episodes = state.episodes.map { ep in
            var copy = ep
            copy.userData.watched = watched
            if watched { copy.userData.playbackPositionMs = 0 }
            return copy
        }
    }

    private func refreshSeriesUnwatchedCount() async {
        guard let series = state.series else { return }
        let seasonId = state.selectedSeasonId
        if case .series(let updated) = try? await api.itemDetail(id: series.id) {
            state.series = updated
        }
        if let seasonId {
            if let eps = try? await api.episodes(seasonId: seasonId) {
                state.episodes = eps
            }
        }
    }

    public nonisolated static func isSeriesWatched(_ series: SeriesDetail) -> Bool {
        series.episodeCount > 0 && (series.userData.unwatchedEpisodeCount ?? series.episodeCount) == 0
    }

    public nonisolated static func isSeasonWatched(_ episodes: [EpisodeSummary]) -> Bool {
        !episodes.isEmpty && episodes.allSatisfy { $0.userData.watched == true }
    }
}
