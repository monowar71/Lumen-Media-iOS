import Foundation
import Combine

public struct SearchUiState: Equatable, Sendable {
    public var query: String = ""
    public var loading: Bool = false
    public var error: String?
    public var movies: [MediaItemSummary] = []
    public var series: [MediaItemSummary] = []
    public var episodes: [EpisodeSummary] = []
    public var baseUrl: String = ""

    public var isEmpty: Bool {
        movies.isEmpty && series.isEmpty && episodes.isEmpty
    }
}

@MainActor
public final class SearchViewModel: ObservableObject {
    @Published public private(set) var state = SearchUiState()

    private let api: any LumenMediaServing
    private let settingsStore: SettingsStore
    private var searchTask: Task<Void, Never>?

    public init(api: any LumenMediaServing, settingsStore: SettingsStore) {
        self.api = api
        self.settingsStore = settingsStore
    }

    public func onQueryChange(_ q: String) {
        state.query = q
        searchTask?.cancel()
        guard q.count > 1 else {
            state.movies = []
            state.series = []
            state.episodes = []
            state.loading = false
            state.error = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    public func search() async {
        let q = state.query
        guard q.count > 1 else { return }
        state.loading = true
        state.error = nil
        let baseUrl = settingsStore.currentSettings.baseUrl
        do {
            let result = try await api.search(q: q, limit: 20)
            state.loading = false
            state.movies = result.movies
            state.series = result.series
            state.episodes = result.episodes
            state.baseUrl = baseUrl
        } catch is CancellationError {
            // ignore
        } catch {
            state.loading = false
            state.error = error.lumenUserMessage("Search failed")
        }
    }
}
