import XCTest
@testable import LumenMediaCore

final class UrlUtilsTests: XCTestCase {
    func testNormalizeBaseUrl_stripsTrailingSlash_andAddsScheme() {
        XCTAssertEqual(UrlUtils.normalizeBaseUrl("example.com/"), "http://example.com")
        XCTAssertEqual(UrlUtils.normalizeBaseUrl("https://host:8096/"), "https://host:8096")
        XCTAssertEqual(UrlUtils.normalizeBaseUrl("  http://host  "), "http://host")
        XCTAssertEqual(UrlUtils.normalizeBaseUrl(""), "")
        XCTAssertEqual(UrlUtils.normalizeBaseUrl("http://host///"), "http://host")
    }

    func testAbsoluteUrl_joinsRelativePaths_andPassthroughAbsolute() {
        XCTAssertEqual(
            UrlUtils.absoluteUrl(baseUrl: "http://host:8096", pathOrUrl: "/api/v1/x"),
            "http://host:8096/api/v1/x"
        )
        XCTAssertEqual(
            UrlUtils.absoluteUrl(baseUrl: "http://host:8096/", pathOrUrl: "api/v1/x"),
            "http://host:8096/api/v1/x"
        )
        XCTAssertEqual(
            UrlUtils.absoluteUrl(baseUrl: "http://host:8096", pathOrUrl: "http://cdn/img"),
            "http://cdn/img"
        )
        XCTAssertEqual(
            UrlUtils.absoluteUrl(baseUrl: "http://host:8096", pathOrUrl: "https://cdn/img"),
            "https://cdn/img"
        )
    }

    func testArtworkUrl_addsResizeParams_andOptionalToken() {
        let url = UrlUtils.artworkUrl(
            baseUrl: "http://host:8096",
            path: "/api/v1/items/1/artwork/Poster",
            width: 240,
            height: 360,
            quality: 80
        )
        XCTAssertNotNil(url)
        let absolute = url!.absoluteString
        XCTAssertTrue(absolute.hasPrefix("http://host:8096/api/v1/items/1/artwork/Poster?"))
        XCTAssertTrue(absolute.contains("w=240"))
        XCTAssertTrue(absolute.contains("h=360"))
        XCTAssertTrue(absolute.contains("quality=80"))
        XCTAssertFalse(absolute.contains("access_token"))

        let withToken = UrlUtils.artworkUrl(
            baseUrl: "http://host:8096",
            path: "/api/v1/items/1/artwork/Poster",
            width: 100,
            accessToken: "tok&en"
        )
        XCTAssertTrue(withToken!.absoluteString.contains("access_token="))
        XCTAssertTrue(withToken!.absoluteString.contains("w=100"))
    }

    func testArtworkUrl_nilOrEmptyPath_returnsNil() {
        XCTAssertNil(UrlUtils.artworkUrl(baseUrl: "http://host", path: nil))
        XCTAssertNil(UrlUtils.artworkUrl(baseUrl: "http://host", path: ""))
    }
}
