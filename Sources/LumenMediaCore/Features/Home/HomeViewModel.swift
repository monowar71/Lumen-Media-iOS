import Foundation
import Combine

public struct HomeUiState: Equatable, Sendable {
    public var loading: Bool = true
    public var error: String?
    public var sections: [HomeSection] = []
    public var baseUrl: String = ""

    public init(
        loading: Bool = true,
        error: String? = nil,
        sections: [HomeSection] = [],
        baseUrl: String = ""
    ) {
        self.loading = loading
        self.error = error
        self.sections = sections
        self.baseUrl = baseUrl
    }

    public var heroItem: MediaItemSummary? {
        for section in sections {
            if let item = section.items.first(where: {
                $0.artwork.backdrop != nil || $0.artwork.poster != nil
            }) {
                return item
            }
        }
        return sections.first?.items.first
    }
}

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var state = HomeUiState()

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
            let home = try await api.home()
            state.loading = false
            state.sections = home.sections.filter { !$0.items.isEmpty }
            state.baseUrl = baseUrl
        } catch {
            state.loading = false
            state.error = error.lumenUserMessage("Failed to load home")
        }
    }
}
