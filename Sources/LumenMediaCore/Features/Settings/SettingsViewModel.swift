import Foundation
import Combine

public struct SettingsUiState: Equatable, Sendable {
    public var baseUrl: String = ""
    public var lanCapKbps: Int = 0
    public var externalCapKbps: Int = 8_000
    public var preferredMode: String = "auto"
    public var locale: String = "ru"
    public var maxCacheBytes: Int64 = AppSettings.defaultMaxCacheBytes
    public var libraries: [LibraryDto] = []
    public var jobs: [JobDto] = []
    public var serverSettings: ServerSettingsDto?
    public var loadingLibraries: Bool = false
    public var error: String?
    public var savedMessage: String?
    public var isAdmin: Bool = false
    public var newLibraryName: String = ""
    public var newLibraryType: String = "Movies"
    public var newLibraryPath: String = ""
    public var offlineSummary = OfflineCacheSummary()
    public var offlineEntries: [OfflineCachedItem] = []
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public private(set) var state = SettingsUiState()

    private let api: any LumenMediaServing
    private let settingsStore: SettingsStore
    private let sessionStore: SessionStore
    private let offline: OfflineDownloadManager?
    private var cancellables = Set<AnyCancellable>()

    public init(
        api: any LumenMediaServing,
        settingsStore: SettingsStore,
        sessionStore: SessionStore,
        offline: OfflineDownloadManager? = nil
    ) {
        self.api = api
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.offline = offline
        let s = settingsStore.currentSettings
        state.baseUrl = s.baseUrl
        state.lanCapKbps = s.lanCapKbps
        state.externalCapKbps = s.externalCapKbps
        state.preferredMode = s.preferredMode
        state.locale = s.locale
        state.maxCacheBytes = s.maxCacheBytes
        state.isAdmin = sessionStore.currentSession?.role.caseInsensitiveCompare("Admin") == .orderedSame
        if let offline {
            state.offlineSummary = offline.summary
            state.offlineEntries = offline.entries
            offline.$summary
                .combineLatest(offline.$entries)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] summary, entries in
                    self?.state.offlineSummary = summary
                    self?.state.offlineEntries = entries
                }
                .store(in: &cancellables)
        }
    }

    public func onBaseUrlChange(_ v: String) { state.baseUrl = v; state.savedMessage = nil }
    public func onLanCapChange(_ v: Int) { state.lanCapKbps = v }
    public func onExternalCapChange(_ v: Int) { state.externalCapKbps = v }
    public func onPreferredModeChange(_ v: String) { state.preferredMode = v }
    public func onLocaleChange(_ v: String) { state.locale = v }
    public func onMaxCacheGibChange(_ gib: Double) {
        if gib <= 0 {
            state.maxCacheBytes = 0
        } else {
            state.maxCacheBytes = Int64(gib * 1024 * 1024 * 1024)
        }
    }
    public func onNewLibraryName(_ v: String) { state.newLibraryName = v }
    public func onNewLibraryType(_ v: String) { state.newLibraryType = v }
    public func onNewLibraryPath(_ v: String) { state.newLibraryPath = v }

    public func saveClientSettings() {
        settingsStore.setBaseUrl(state.baseUrl)
        settingsStore.setLanCap(state.lanCapKbps)
        settingsStore.setExternalCap(state.externalCapKbps)
        settingsStore.setPreferredMode(state.preferredMode)
        settingsStore.setLocale(state.locale)
        settingsStore.setMaxCacheBytes(state.maxCacheBytes)
        state.savedMessage = "Saved"
    }

    public func removeOffline(_ mediaId: String) async {
        await offline?.remove(mediaId)
    }

    public func clearOfflineCache() async {
        await offline?.clearAll()
    }

    public func removeFailedOffline() async {
        await offline?.removeFailed()
    }

    public func loadAdminData() async {
        guard state.isAdmin else { return }
        state.loadingLibraries = true
        do {
            async let libs = api.libraries()
            async let jobs = api.jobs(page: 1, pageSize: 50)
            async let server = api.serverSettings()
            state.libraries = try await libs
            state.jobs = try await jobs
            state.serverSettings = try await server
            state.loadingLibraries = false
        } catch {
            state.loadingLibraries = false
            state.error = error.lumenUserMessage("Failed to load admin data")
        }
    }

    public func createLibrary() async {
        let name = state.newLibraryName.trimmingCharacters(in: .whitespaces)
        let path = state.newLibraryPath.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !path.isEmpty else {
            state.error = "Name and path are required"
            return
        }
        do {
            _ = try await api.createLibrary(
                CreateLibraryRequest(name: name, type: state.newLibraryType, paths: [path])
            )
            state.newLibraryName = ""
            state.newLibraryPath = ""
            await loadAdminData()
        } catch {
            state.error = error.lumenUserMessage("Failed to create library")
        }
    }

    public func deleteLibrary(_ id: String) async {
        do {
            try await api.deleteLibrary(id: id)
            await loadAdminData()
        } catch {
            state.error = error.lumenUserMessage("Failed to delete library")
        }
    }

    public func scanLibrary(_ id: String) async {
        do {
            _ = try await api.scanLibrary(id: id)
            await loadAdminData()
        } catch {
            state.error = error.lumenUserMessage("Failed to start scan")
        }
    }
}
