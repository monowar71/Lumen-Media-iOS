import XCTest
@testable import LumenMediaCore

final class PlaybackSourceTests: XCTestCase {
    private let base = "http://10.0.2.2:8096"

    func testDirectPlay_returnsDirectUrl_withoutCacheToken() {
        let decision = PlaybackDecisionResponse(
            sessionId: "s1",
            method: "DirectPlay",
            streamUrl: "/api/v1/items/1/download"
        )
        let source = resolvePlaybackSource(decision: decision, baseUrl: base, cacheToken: "42")
        XCTAssertEqual(source, .direct(url: "http://10.0.2.2:8096/api/v1/items/1/download"))
    }

    func testHls_appendsCacheToken() {
        let decision = PlaybackDecisionResponse(
            sessionId: "s1",
            method: "Transcode",
            streamUrl: "/api/v1/stream/s1/master.m3u8"
        )
        let source = resolvePlaybackSource(decision: decision, baseUrl: "http://host", cacheToken: "42")
        guard case .hls(let url) = source else {
            return XCTFail("Expected HLS source")
        }
        XCTAssertTrue(url.contains("_cp=42"))
        XCTAssertTrue(url.hasPrefix("http://host/api/v1/stream/s1/master.m3u8"))
    }

    func testHls_withoutCacheToken_leavesUrlClean() {
        let decision = PlaybackDecisionResponse(
            sessionId: "s1",
            method: "Transcode",
            streamUrl: "/api/v1/stream/s1/index.m3u8"
        )
        let source = resolvePlaybackSource(decision: decision, baseUrl: base, cacheToken: nil)
        XCTAssertEqual(source, .hls(url: "\(base)/api/v1/stream/s1/index.m3u8"))
    }

    func testHls_appendsCacheToken_withExistingQuery() {
        let decision = PlaybackDecisionResponse(
            sessionId: "s1",
            method: "Hls",
            streamUrl: "/stream?token=abc"
        )
        let source = resolvePlaybackSource(decision: decision, baseUrl: base, cacheToken: "9")
        guard case .hls(let url) = source else {
            return XCTFail("Expected HLS")
        }
        XCTAssertTrue(url.contains("token=abc"))
        XCTAssertTrue(url.contains("_cp=9"))
    }

    func testDirectPlay_appendsAccessToken() {
        let decision = PlaybackDecisionResponse(
            sessionId: "s1",
            method: "DirectPlay",
            streamUrl: "/api/v1/items/1/download"
        )
        let source = resolvePlaybackSource(
            decision: decision,
            baseUrl: base,
            accessToken: "tok"
        )
        guard case .direct(let url) = source else {
            return XCTFail("Expected DirectPlay")
        }
        XCTAssertTrue(url.contains("access_token=tok"))
        XCTAssertFalse(url.contains("_cp="))
    }

    func testHls_appendsAccessTokenAndCacheToken() {
        let decision = PlaybackDecisionResponse(
            sessionId: "s1",
            method: "Transcode",
            streamUrl: "/api/v1/stream/s1/master.m3u8"
        )
        let source = resolvePlaybackSource(
            decision: decision,
            baseUrl: "http://host",
            cacheToken: "42",
            accessToken: "secret"
        )
        guard case .hls(let url) = source else {
            return XCTFail("Expected HLS source")
        }
        XCTAssertTrue(url.contains("_cp=42"))
        XCTAssertTrue(url.contains("access_token=secret"))
    }

    func testQualityMode_autoAndManual() {
        let available = [
            QualityOption(id: "auto", label: "Auto", adaptive: true),
            QualityOption(id: "abr", label: "ABR", adaptive: true),
            QualityOption(id: "1080p", label: "1080p", height: 1080, bitrateKbps: 8_000),
        ]
        XCTAssertEqual(QualityMode.mode(for: "auto", available: available), "auto")
        XCTAssertEqual(QualityMode.mode(for: "abr", available: available), "auto")
        XCTAssertEqual(QualityMode.mode(for: "1080p", available: available), "manual")
        XCTAssertEqual(QualityMode.mode(for: "unknown", available: available), "manual")
    }
}
