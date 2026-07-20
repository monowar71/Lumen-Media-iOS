import Foundation
import Combine

public struct LibraryUiState: Equatable, Sendable {
    public var loading: Bool = true
    public var error: String?
    public var library: LibraryDto?
    public var items: [MediaItemSummary] = []
    public var libraries: [LibraryDto] = []
    public var baseUrl: String = ""
    public var query: String = ""
    public var sort: LibrarySort = .added
    public var orderAscending: Bool = false
    public var genre: String?
    public var year: Int?
    public var watchedFilter: WatchedFilter = .all
    public var inProgressFirst: Bool = false
    public var page: Int = 1
    public var hasMore: Bool = false
    public var loadingMore: Bool = false

    public enum WatchedFilter: String, CaseIterable, Sendable {
        case all
        case watched
        case unwatched
    }
}

@MainActor
public final class LibraryViewModel: ObservableObject {
    @Published public private(set) var state = LibraryUiState()

    private let api: any LumenMediaServing
    private let settingsStore: SettingsStore
    private var libraryId: String
    private var queryTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    public init(
        libraryId: String,
        api: any LumenMediaServing,
        settingsStore: SettingsStore
    ) {
        self.libraryId = libraryId
        self.api = api
        self.settingsStore = settingsStore
        state.sort = settingsStore.currentSettings.librarySort
        state.inProgressFirst = settingsStore.currentSettings.libraryInProgressFirst
    }

    public func setLibraryId(_ id: String) {
        guard id != libraryId else { return }
        libraryId = id
        Task { await load() }
    }

    public func onQueryChange(_ q: String) {
        guard q != state.query else { return }
        state.query = q
        queryTask?.cancel()
        queryTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    public func onSortChange(_ sort: LibrarySort) {
        guard sort != state.sort else { return }
        state.sort = sort
        settingsStore.setLibrarySort(sort)
        Task { await load() }
    }

    public func toggleOrder() {
        state.orderAscending.toggle()
        Task { await load() }
    }

    public func onGenreChange(_ genre: String?) {
        state.genre = genre
        Task { await load() }
    }

    public func onYearChange(_ year: Int?) {
        state.year = year
        Task { await load() }
    }

    public func onWatchedFilterChange(_ filter: LibraryUiState.WatchedFilter) {
        state.watchedFilter = filter
        Task { await load() }
    }

    public func onInProgressFirstChange(_ enabled: Bool) {
        guard enabled != state.inProgressFirst else { return }
        state.inProgressFirst = enabled
        state.items = Self.orderItems(state.items, inProgressFirst: enabled)
        settingsStore.setLibraryInProgressFirst(enabled)
    }

    public func refresh() async {
        queryTask?.cancel()
        await load()
    }

    public func loadMore() {
        guard !state.loading, !state.loadingMore, state.hasMore else { return }
        let nextPage = state.page + 1
        let query = state.query.isEmpty ? nil : state.query
        let watched: Bool? = {
            switch state.watchedFilter {
            case .all: return nil
            case .watched: return true
            case .unwatched: return false
            }
        }()
        state.loadingMore = true
        loadMoreTask = Task {
            do {
                let result = try await api.libraryItems(
                    id: libraryId,
                    page: nextPage,
                    pageSize: 40,
                    sort: state.sort.apiSort,
                    order: state.orderAscending ? "asc" : state.sort.apiOrder,
                    watched: watched,
                    genre: state.genre,
                    year: state.year,
                    q: query
                )
                let merged = Self.orderItems(
                    (state.items + result.items).uniqued(by: \.id),
                    inProgressFirst: state.inProgressFirst
                )
                state.loadingMore = false
                state.items = merged
                state.page = nextPage
                state.hasMore = Self.hasMore(result)
            } catch is CancellationError {
                // ignore
            } catch {
                state.loadingMore = false
            }
        }
    }

    private func load() async {
        loadMoreTask?.cancel()
        state.loading = true
        state.error = nil
        state.loadingMore = false
        let baseUrl = settingsStore.currentSettings.baseUrl
        let watched: Bool? = {
            switch state.watchedFilter {
            case .all: return nil
            case .watched: return true
            case .unwatched: return false
            }
        }()
        do {
            let libraries = try await api.libraries()
            let library = libraries.first { $0.id == libraryId }
            let page = try await api.libraryItems(
                id: libraryId,
                page: 1,
                pageSize: 40,
                sort: state.sort.apiSort,
                order: state.orderAscending ? "asc" : state.sort.apiOrder,
                watched: watched,
                genre: state.genre,
                year: state.year,
                q: state.query.isEmpty ? nil : state.query
            )
            state.loading = false
            state.libraries = libraries
            state.library = library
            state.items = Self.orderItems(page.items, inProgressFirst: state.inProgressFirst)
            state.page = 1
            state.hasMore = Self.hasMore(page)
            state.baseUrl = baseUrl
        } catch is CancellationError {
            // ignore
        } catch {
            state.loading = false
            state.error = error.lumenUserMessage("Failed to load library")
        }
    }

    public nonisolated static func hasMore(_ result: PagedResult<MediaItemSummary>) -> Bool {
        if result.totalPages > 0 {
            return result.page < result.totalPages
        }
        return result.items.count >= result.pageSize
    }

    public nonisolated static func orderItems(
        _ items: [MediaItemSummary],
        inProgressFirst: Bool
    ) -> [MediaItemSummary] {
        guard inProgressFirst else { return items }
        let started = items.filter {
            $0.userData.watched != true && ($0.userData.playbackPositionMs ?? 0) > 0
        }
        let rest = items.filter {
            !($0.userData.watched != true && ($0.userData.playbackPositionMs ?? 0) > 0)
        }
        return started + rest
    }
}

private extension Array {
    func uniqued<Key: Hashable>(by key: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert($0[keyPath: key]).inserted }
    }
}
