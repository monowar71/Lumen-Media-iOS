import Foundation
import Combine
import LumenMediaCore

/// Shared app dependencies injected via `@EnvironmentObject`.
@MainActor
final class AppEnvironment: ObservableObject {
    let sessionStore: SessionStore
    let settingsStore: SettingsStore
    let api: LumenMediaAPIClient
    let offline: OfflineDownloadManager

    init(
        sessionStore: SessionStore = SessionStore(),
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
        self.api = LumenMediaAPIClient(
            sessionStore: sessionStore,
            settingsStore: settingsStore
        )
        self.offline = OfflineDownloadManager(
            settingsStore: settingsStore,
            sessionStore: sessionStore
        )
    }
}

// MARK: - Navigation

enum AppDestination: Hashable {
    case item(String)
    case library(String)
}

struct PlayerRoute: Identifiable, Hashable {
    var id: String { "\(itemId)-\(resumeMs)" }
    let itemId: String
    let resumeMs: Int64

    init(itemId: String, resumeMs: Int64 = 0) {
        self.itemId = itemId
        self.resumeMs = resumeMs
    }
}
