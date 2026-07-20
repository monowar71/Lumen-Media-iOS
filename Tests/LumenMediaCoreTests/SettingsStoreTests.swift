import XCTest
@testable import LumenMediaCore

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.lumen.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPersistCapsAndBaseUrl() {
        let store = SettingsStore(defaults: defaults)
        store.setBaseUrl("example.com/")
        store.setLanCap(40_000)
        store.setExternalCap(6_000)

        XCTAssertEqual(store.currentSettings.baseUrl, "http://example.com")
        XCTAssertEqual(store.currentSettings.lanCapKbps, 40_000)
        XCTAssertEqual(store.currentSettings.externalCapKbps, 6_000)

        // Reload from the same suite to prove persistence.
        let reloaded = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(reloaded.currentSettings.baseUrl, "http://example.com")
        XCTAssertEqual(reloaded.currentSettings.lanCapKbps, 40_000)
        XCTAssertEqual(reloaded.currentSettings.externalCapKbps, 6_000)
    }

    func testCapFor_usesConfiguredOrDefault() {
        let store = SettingsStore(defaults: defaults)
        store.setLanCap(0)
        store.setExternalCap(8_000)

        XCTAssertEqual(store.capFor(kind: .lan), 100_000)
        XCTAssertEqual(store.capFor(kind: .external), 8_000)

        store.setLanCap(50_000)
        XCTAssertEqual(store.capFor(kind: .lan), 50_000)
    }

    func testLibraryPreferencesPersist() {
        let store = SettingsStore(defaults: defaults)
        store.setLibrarySort(.title)
        store.setLibraryInProgressFirst(true)
        store.setPreferredMode("direct")
        store.setLocale("en")

        let reloaded = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(reloaded.currentSettings.librarySort, .title)
        XCTAssertTrue(reloaded.currentSettings.libraryInProgressFirst)
        XCTAssertEqual(reloaded.currentSettings.preferredMode, "direct")
        XCTAssertEqual(reloaded.currentSettings.locale, "en")
    }
}
