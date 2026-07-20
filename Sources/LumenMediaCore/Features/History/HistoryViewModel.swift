import Foundation
import Combine

public struct HistoryUiState: Equatable, Sendable {
    public var loading: Bool = true
    public var error: String?
    public var entries: [HistoryEntry] = []
    public var page: Int = 1
    public var hasMore: Bool = false
    public var loadingMore: Bool = false
    public var clearing: Bool = false
    public var baseUrl: String = ""
}

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public private(set) var state = HistoryUiState()

    private let api: any LumenMediaServing
    private let settingsStore: SettingsStore

    public init(api: any LumenMediaServing, settingsStore: SettingsStore) {
        self.api = api
        self.settingsStore = settingsStore
    }

    public func refresh() async {
        state.loading = true
        state.error = nil
        let baseUrl = settingsStore.currentSettings.baseUrl
        do {
            let page = try await api.history(page: 1, pageSize: 40)
            state.loading = false
            state.entries = page.items
            state.page = 1
            state.hasMore = page.totalPages > 0
                ? page.page < page.totalPages
                : page.items.count >= page.pageSize
            state.baseUrl = baseUrl
        } catch {
            state.loading = false
            state.error = error.lumenUserMessage("Failed to load history")
        }
    }

    public func loadMore() async {
        guard !state.loading, !state.loadingMore, state.hasMore else { return }
        state.loadingMore = true
        let next = state.page + 1
        do {
            let page = try await api.history(page: next, pageSize: 40)
            state.loadingMore = false
            state.entries += page.items
            state.page = next
            state.hasMore = page.totalPages > 0
                ? page.page < page.totalPages
                : page.items.count >= page.pageSize
        } catch {
            state.loadingMore = false
        }
    }

    public func clear() async {
        state.clearing = true
        do {
            try await api.clearHistory()
            state.clearing = false
            state.entries = []
            state.hasMore = false
        } catch {
            state.clearing = false
            state.error = error.lumenUserMessage("Failed to clear history")
        }
    }
}
