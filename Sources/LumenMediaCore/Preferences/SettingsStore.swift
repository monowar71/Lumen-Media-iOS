import Foundation
import Combine

public final class SettingsStore: ObservableObject, @unchecked Sendable {
    @Published public private(set) var settings: AppSettings

    private let defaults: UserDefaults
    private let lock = NSLock()

    private enum Keys {
        static let baseUrl = "lumen.baseUrl"
        static let lanCap = "lumen.lanCap"
        static let externalCap = "lumen.externalCap"
        static let mode = "lumen.preferredMode"
        static let librarySort = "lumen.librarySort"
        static let inProgressFirst = "lumen.libraryInProgressFirst"
        static let locale = "lumen.locale"
        static let maxCacheBytes = "lumen.maxCacheBytes"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedCache = defaults.object(forKey: Keys.maxCacheBytes) as? Int64
        self.settings = AppSettings(
            baseUrl: UrlUtils.normalizeBaseUrl(
                defaults.string(forKey: Keys.baseUrl) ?? "http://127.0.0.1:8096"
            ),
            lanCapKbps: defaults.object(forKey: Keys.lanCap) as? Int ?? 0,
            externalCapKbps: defaults.object(forKey: Keys.externalCap) as? Int ?? 8_000,
            preferredMode: defaults.string(forKey: Keys.mode) ?? "auto",
            librarySort: LibrarySort(rawValue: defaults.string(forKey: Keys.librarySort) ?? "") ?? .added,
            libraryInProgressFirst: defaults.bool(forKey: Keys.inProgressFirst),
            locale: defaults.string(forKey: Keys.locale) ?? "ru",
            maxCacheBytes: storedCache ?? AppSettings.defaultMaxCacheBytes
        )
    }

    public var currentSettings: AppSettings {
        lock.lock(); defer { lock.unlock() }
        return settings
    }

    public func setBaseUrl(_ url: String) {
        mutate { $0.baseUrl = UrlUtils.normalizeBaseUrl(url) }
        defaults.set(currentSettings.baseUrl, forKey: Keys.baseUrl)
    }

    public func setLanCap(_ kbps: Int) {
        mutate { $0.lanCapKbps = max(0, kbps) }
        defaults.set(currentSettings.lanCapKbps, forKey: Keys.lanCap)
    }

    public func setExternalCap(_ kbps: Int) {
        mutate { $0.externalCapKbps = max(0, kbps) }
        defaults.set(currentSettings.externalCapKbps, forKey: Keys.externalCap)
    }

    public func setPreferredMode(_ mode: String) {
        mutate { $0.preferredMode = mode }
        defaults.set(mode, forKey: Keys.mode)
    }

    public func setLibrarySort(_ sort: LibrarySort) {
        mutate { $0.librarySort = sort }
        defaults.set(sort.rawValue, forKey: Keys.librarySort)
    }

    public func setLibraryInProgressFirst(_ enabled: Bool) {
        mutate { $0.libraryInProgressFirst = enabled }
        defaults.set(enabled, forKey: Keys.inProgressFirst)
    }

    public func setLocale(_ locale: String) {
        mutate { $0.locale = locale }
        defaults.set(locale, forKey: Keys.locale)
    }

    public func setMaxCacheBytes(_ bytes: Int64) {
        mutate { $0.maxCacheBytes = max(0, bytes) }
        defaults.set(currentSettings.maxCacheBytes, forKey: Keys.maxCacheBytes)
    }

    public func capFor(kind: ConnectionKind) -> Int {
        let s = currentSettings
        switch kind {
        case .external:
            return s.externalCapKbps > 0 ? s.externalCapKbps : 100_000
        case .lan:
            return s.lanCapKbps > 0 ? s.lanCapKbps : 100_000
        }
    }

    private func mutate(_ block: (inout AppSettings) -> Void) {
        lock.lock()
        block(&settings)
        lock.unlock()
        objectWillChange.send()
    }
}
