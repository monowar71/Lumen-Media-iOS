import Foundation

public enum PlaybackSource: Equatable, Sendable {
    case direct(url: String)
    case hls(url: String)

    public var url: String {
        switch self {
        case .direct(let url), .hls(let url): return url
        }
    }
}

/// Maps a server playback decision to a concrete AVPlayer source.
/// Mirrors client_web `resolvePlaybackSource` / Android `resolvePlaybackSource`.
public func resolvePlaybackSource(
    decision: PlaybackDecisionResponse,
    baseUrl: String,
    cacheToken: String? = nil,
    accessToken: String? = nil
) -> PlaybackSource {
    var url = UrlUtils.absoluteUrl(baseUrl: baseUrl, pathOrUrl: decision.streamUrl)
    if let cacheToken, !cacheToken.isEmpty, decision.method != "DirectPlay" {
        let separator = url.contains("?") ? "&" : "?"
        url += "\(separator)_cp=\(cacheToken)"
    }
    url = UrlUtils.withAccessToken(url, token: accessToken)
    if decision.method == "DirectPlay" {
        return .direct(url: url)
    }
    return .hls(url: url)
}

public enum QualityMode {
    /// Determines auto vs manual from a quality id and available options.
    public static func mode(for qualityId: String, available: [QualityOption]) -> String {
        if qualityId == "auto" { return "auto" }
        if available.contains(where: { $0.id == qualityId && $0.adaptive == true }) {
            return "auto"
        }
        return "manual"
    }
}
