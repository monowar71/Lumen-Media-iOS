import XCTest
@testable import LumenMediaCore

final class OfflineDownloadManagerTests: XCTestCase {
    func testGuessExtension_fromContentDisposition() {
        let ext = OfflineDownloadManager.guessExtension(
            contentType: nil,
            contentDisposition: #"attachment; filename="Show.S01E01.mkv""#
        )
        XCTAssertEqual(ext, "mkv")
    }

    func testGuessExtension_fromContentType() {
        XCTAssertEqual(
            OfflineDownloadManager.guessExtension(contentType: "video/mp4", contentDisposition: nil),
            "mp4"
        )
        XCTAssertEqual(
            OfflineDownloadManager.guessExtension(contentType: "video/x-matroska", contentDisposition: nil),
            "mkv"
        )
        XCTAssertEqual(
            OfflineDownloadManager.guessExtension(contentType: nil, contentDisposition: nil),
            "bin"
        )
    }

    func testOfflineCachedItem_progress() {
        let ready = OfflineCachedItem(
            mediaId: "1",
            title: "A",
            status: .ready,
            bytesDownloaded: 100,
            bytesTotal: 100
        )
        XCTAssertEqual(ready.progress, 1)

        let partial = OfflineCachedItem(
            mediaId: "2",
            title: "B",
            status: .downloading,
            bytesDownloaded: 25,
            bytesTotal: 100
        )
        XCTAssertEqual(partial.progress, 0.25, accuracy: 0.001)
    }

    func testFileStore_partialAndReadyPaths() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumen-offline-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = OfflineFileStore(root: tmp)
        let partial = store.partialFile(mediaId: "ep1")
        XCTAssertTrue(partial.lastPathComponent.hasSuffix(".partial"))
        let ready = store.readyFile(mediaId: "ep1", extension: "mp4")
        XCTAssertEqual(ready.lastPathComponent, "ep1.mp4")
        try Data([1, 2, 3]).write(to: ready)
        XCTAssertEqual(store.findReadyFile(mediaId: "ep1")?.lastPathComponent, "ep1.mp4")
        store.deleteMediaFiles(mediaId: "ep1")
        XCTAssertNil(store.findReadyFile(mediaId: "ep1"))
    }
}
