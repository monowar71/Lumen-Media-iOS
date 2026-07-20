import Foundation

public enum UrlUtils {
    public static func normalizeBaseUrl(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty { return url }
        if !url.contains("://") {
            url = "http://\(url)"
        }
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }

    public static func absoluteUrl(baseUrl: String, pathOrUrl: String) -> String {
        if pathOrUrl.hasPrefix("http://") || pathOrUrl.hasPrefix("https://") {
            return pathOrUrl
        }
        let base = normalizeBaseUrl(baseUrl)
        if pathOrUrl.hasPrefix("/") {
            return base + pathOrUrl
        }
        return base + "/" + pathOrUrl
    }

    /// Appends `access_token` for AVPlayer / AsyncImage (no Authorization header).
    public static func withAccessToken(_ url: String, token: String?) -> String {
        guard let token, !token.isEmpty else { return url }
        guard var components = URLComponents(string: url) else { return url }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "access_token" }
        items.append(URLQueryItem(name: "access_token", value: token))
        components.queryItems = items
        return components.url?.absoluteString ?? url
    }

    /// Artwork URL with resize params. Token is appended for AsyncImage (no shared auth header).
    public static func artworkUrl(
        baseUrl: String,
        path: String?,
        width: Int? = nil,
        height: Int? = nil,
        quality: Int = 80,
        accessToken: String? = nil
    ) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        var absolute = absoluteUrl(baseUrl: baseUrl, pathOrUrl: path)
        var params: [String] = []
        if let width { params.append("w=\(width)") }
        if let height { params.append("h=\(height)") }
        params.append("quality=\(quality)")
        if let accessToken, !accessToken.isEmpty {
            params.append("access_token=\(accessToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? accessToken)")
        }
        let separator = absolute.contains("?") ? "&" : "?"
        absolute += separator + params.joined(separator: "&")
        return URL(string: absolute)
    }
}

public enum Formatters {
    public static func runtime(_ ms: Int64?) -> String {
        guard let ms, ms > 0 else { return "" }
        let totalMinutes = Int((Double(ms) / 60_000.0).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    public static func time(_ ms: Int64) -> String {
        let clamped = max(0, ms)
        let totalSeconds = Int(clamped / 1000)
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    public static func progressFraction(positionMs: Int64?, durationMs: Int64?) -> Double {
        guard let positionMs, let durationMs, durationMs > 0 else { return 0 }
        return min(1, max(0, Double(positionMs) / Double(durationMs)))
    }

    public static func trackLanguage(_ code: String?) -> String {
        guard let code, !code.isEmpty else { return "Unknown" }
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
}
