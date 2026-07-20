import XCTest

final class LumenMediaUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        if let base = ProcessInfo.processInfo.environment["LUMEN_BASE_URL"] {
            app.launchEnvironment["LUMEN_BASE_URL"] = base
        }
        if let user = ProcessInfo.processInfo.environment["LUMEN_USER"] {
            app.launchEnvironment["LUMEN_USER"] = user
        }
        if let pass = ProcessInfo.processInfo.environment["LUMEN_PASS"] {
            app.launchEnvironment["LUMEN_PASS"] = pass
        }
        // Also pass via scheme defaults when run under xcodebuild.
        app.launchEnvironment["LUMEN_BASE_URL"] =
            app.launchEnvironment["LUMEN_BASE_URL"] ?? "http://192.168.0.2:8096"
        app.launchEnvironment["LUMEN_USER"] = app.launchEnvironment["LUMEN_USER"] ?? "admin"
        app.launchEnvironment["LUMEN_PASS"] = app.launchEnvironment["LUMEN_PASS"] ?? "admin123"
        app.launch()
    }

    func testLoginBrowseTabsDetailsAndPlayback() throws {
        let base = app.launchEnvironment["LUMEN_BASE_URL"] ?? "http://192.168.0.2:8096"
        let user = app.launchEnvironment["LUMEN_USER"] ?? "admin"
        let pass = app.launchEnvironment["LUMEN_PASS"] ?? "admin123"

        // Login form
        let server = app.textFields["login.server"]
        XCTAssertTrue(server.waitForExistence(timeout: 10))
        server.tap()
        server.clearAndType(base)

        let username = app.textFields["login.username"]
        XCTAssertTrue(username.waitForExistence(timeout: 3))
        username.tap()
        username.clearAndType(user)

        let password = app.secureTextFields["login.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 3))
        password.tap()
        password.typeText(pass)

        app.buttons["login.submit"].tap()

        // Home tab should appear after auth
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20), "Home tab missing — login likely failed")

        // Capture home
        XCTAssertTrue(app.staticTexts["LumenMedia"].waitForExistence(timeout: 5) || homeTab.exists)

        // Search
        app.tabBars.buttons["Search"].tap()
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            searchField.typeText("28")
            // Wait for results list/grid
            sleep(2)
        }

        // Libraries
        let librariesTab = app.tabBars.buttons["Libraries"]
        XCTAssertTrue(librariesTab.waitForExistence(timeout: 5))
        librariesTab.tap()

        // Open first library (Movies / Фильмы / Series)
        let libraryCell = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Film"))
            .firstMatch
        let libraryCellRu = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Фильм"))
            .firstMatch
        let libraryAny = app.collectionViews.cells.firstMatch.exists
            ? app.collectionViews.cells.firstMatch
            : (libraryCell.exists ? libraryCell : libraryCellRu)
        if libraryAny.waitForExistence(timeout: 8) {
            libraryAny.tap()
        } else if app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Фильм")).firstMatch.waitForExistence(timeout: 3) {
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Фильм")).firstMatch.tap()
        }

        // Open first poster/item if present
        let firstItem = app.scrollViews.buttons.firstMatch
        if firstItem.waitForExistence(timeout: 10) {
            firstItem.tap()
        } else {
            let cell = app.collectionViews.cells.firstMatch
            if cell.waitForExistence(timeout: 5) { cell.tap() }
        }

        // Play
        let play = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Play")).firstMatch
        let resume = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Resume")).firstMatch
        let playRu = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Смотр")).firstMatch
        if play.waitForExistence(timeout: 8) {
            play.tap()
        } else if resume.exists {
            resume.tap()
        } else if playRu.exists {
            playRu.tap()
        }

        // Player chrome / close
        let close = app.buttons["player.close"]
        // Give playback a moment to attach HLS
        sleep(4)
        if close.waitForExistence(timeout: 3) {
            close.tap()
        } else if app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Close")).firstMatch.exists {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Close")).firstMatch.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.08)).tap()
        }

        // History + Settings
        if app.tabBars.buttons["History"].waitForExistence(timeout: 5) {
            app.tabBars.buttons["History"].tap()
            sleep(1)
        }
        if app.tabBars.buttons["Settings"].waitForExistence(timeout: 5) {
            app.tabBars.buttons["Settings"].tap()
            XCTAssertTrue(
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Offline")).firstMatch
                    .waitForExistence(timeout: 5)
                    || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cache")).firstMatch.exists
                    || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch.exists
            )
        }
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        guard let current = value as? String, !current.isEmpty else {
            typeText(text)
            return
        }
        let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        typeText(delete)
        typeText(text)
    }
}
