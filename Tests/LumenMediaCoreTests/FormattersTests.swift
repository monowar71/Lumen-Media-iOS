import XCTest
@testable import LumenMediaCore

final class FormattersTests: XCTestCase {
    func testRuntime_formatsHoursAndMinutes() {
        XCTAssertEqual(Formatters.runtime(nil), "")
        XCTAssertEqual(Formatters.runtime(0), "")
        XCTAssertEqual(Formatters.runtime(-1), "")
        XCTAssertEqual(Formatters.runtime(45 * 60_000), "45m")
        XCTAssertEqual(Formatters.runtime(90 * 60_000), "1h 30m")
        XCTAssertEqual(Formatters.runtime(120 * 60_000), "2h 0m")
    }

    func testTime_formatsClockStyle() {
        XCTAssertEqual(Formatters.time(0), "0:00")
        XCTAssertEqual(Formatters.time(65_000), "1:05")
        XCTAssertEqual(Formatters.time(3_661_000), "1:01:01")
        XCTAssertEqual(Formatters.time(-5_000), "0:00")
    }

    func testProgressFraction_clampsAndGuards() {
        XCTAssertEqual(Formatters.progressFraction(positionMs: nil, durationMs: 100), 0)
        XCTAssertEqual(Formatters.progressFraction(positionMs: 50, durationMs: nil), 0)
        XCTAssertEqual(Formatters.progressFraction(positionMs: 50, durationMs: 0), 0)
        XCTAssertEqual(Formatters.progressFraction(positionMs: 50, durationMs: 100), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Formatters.progressFraction(positionMs: 150, durationMs: 100), 1.0, accuracy: 0.0001)
        XCTAssertEqual(Formatters.progressFraction(positionMs: -10, durationMs: 100), 0, accuracy: 0.0001)
    }
}
