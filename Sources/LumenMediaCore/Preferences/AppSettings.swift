public enum LibrarySort: String, CaseIterable, Sendable, Codable {
    case title
    case year
    case added
    case rating
    case runtime

    /// Alias used in older Android/tests naming.
    public static var name: LibrarySort { .title }

    public var apiSort: String { rawValue }

    public var apiOrder: String {
        switch self {
        case .title: return "asc"
        case .year, .added, .rating, .runtime: return "desc"
        }
    }

    public var displayName: String {
        switch self {
        case .title: return "Title"
        case .year: return "Year"
        case .added: return "Date added"
        case .rating: return "Rating"
        case .runtime: return "Runtime"
        }
    }
}

public struct AppSettings: Equatable, Sendable {
    public var baseUrl: String
    public var lanCapKbps: Int
    public var externalCapKbps: Int
    public var preferredMode: String
    public var librarySort: LibrarySort
    public var libraryInProgressFirst: Bool
    public var locale: String
    /// Max offline cache size in bytes; 0 = unlimited. Default 50 GiB.
    public var maxCacheBytes: Int64

    public init(
        baseUrl: String = "http://127.0.0.1:8096",
        lanCapKbps: Int = 0,
        externalCapKbps: Int = 8_000,
        preferredMode: String = "auto",
        librarySort: LibrarySort = .added,
        libraryInProgressFirst: Bool = false,
        locale: String = "ru",
        maxCacheBytes: Int64 = AppSettings.defaultMaxCacheBytes
    ) {
        self.baseUrl = baseUrl
        self.lanCapKbps = lanCapKbps
        self.externalCapKbps = externalCapKbps
        self.preferredMode = preferredMode
        self.librarySort = librarySort
        self.libraryInProgressFirst = libraryInProgressFirst
        self.locale = locale
        self.maxCacheBytes = maxCacheBytes
    }

    public static let defaultMaxCacheBytes: Int64 = 50 * 1024 * 1024 * 1024
}
