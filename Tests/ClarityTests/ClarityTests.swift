import XCTest
@testable import ClarityShared

final class ClarityTests: XCTestCase {

    // MARK: - App Category Tests

    func testAppCategoryFromBundleId() {
        XCTAssertEqual(AppCategory.from(bundleId: "com.microsoft.VSCode"), .development)
        XCTAssertEqual(AppCategory.from(bundleId: "com.apple.Safari"), .browsers)
        XCTAssertEqual(AppCategory.from(bundleId: "com.tinyspeck.slackmacgap"), .communication)
        XCTAssertEqual(AppCategory.from(bundleId: "com.spotify.client"), .music)
        XCTAssertEqual(AppCategory.from(bundleId: "com.unknown.app"), .other)
    }

    // MARK: - Date Formatting Tests

    func testDateFormatters() {
        let date = Date()
        XCTAssertFalse(DateFormatters.dateOnly.string(from: date).isEmpty)
        XCTAssertFalse(DateFormatters.time.string(from: date).isEmpty)
    }

    func testDurationFormatting() {
        XCTAssertEqual(3600.formattedDuration, "1h 0m")
        XCTAssertEqual(5400.formattedDuration, "1h 30m")
        XCTAssertEqual(1800.formattedDuration, "30m")
        XCTAssertEqual(45.formattedDuration, "<1m")
    }

    func testPercentageFormatting() {
        XCTAssertEqual(85.5.percentageString, "86%")
        XCTAssertEqual(100.0.percentageString, "100%")
        XCTAssertEqual(0.0.percentageString, "0%")
    }

    // MARK: - Model Tests

    func testAppModel() {
        let app = App(
            bundleId: "com.test.app",
            name: "Test App",
            category: .productivity
        )

        XCTAssertEqual(app.bundleId, "com.test.app")
        XCTAssertEqual(app.name, "Test App")
        XCTAssertEqual(app.category, .productivity)
        XCTAssertFalse(app.isDistraction)
    }

    func testMinuteStatModel() {
        let timestamp = Int64(Date().timeIntervalSince1970) / 60 * 60

        let stat = MinuteStat(
            timestamp: timestamp,
            appId: 1,
            keystrokes: 100,
            clicks: 50,
            activeSeconds: 60
        )

        XCTAssertEqual(stat.keystrokes, 100)
        XCTAssertEqual(stat.clicks, 50)
        XCTAssertEqual(stat.activeSeconds, 60)
    }

    func testFocusSessionModel() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(30 * 60) // 30 minutes

        var session = FocusSession(
            startTime: startTime,
            endTime: endTime,
            keystrokes: 500,
            interruptions: 1
        )

        XCTAssertEqual(session.durationSeconds, 30 * 60)
        XCTAssertEqual(session.formattedDuration, "30m")
        XCTAssertTrue(session.isDeepWork) // 30 min with < 3 interruptions

        // Not deep work if too many interruptions
        session.interruptions = 5
        XCTAssertFalse(session.isDeepWork)
    }

    func testDailyStatModel() {
        let stat = DailyStat(
            date: "2024-01-15",
            totalActiveSeconds: 4 * 60 * 60, // 4 hours
            totalFocusSeconds: 2 * 60 * 60,  // 2 hours
            totalKeystrokes: 10000,
            focusScore: 75.0
        )

        XCTAssertEqual(stat.formattedActiveTime, "4h 0m")
        XCTAssertEqual(stat.formattedFocusTime, "2h 0m")
    }

    // MARK: - Date Extension Tests

    func testDateExtensions() {
        let today = Date()
        XCTAssertTrue(today.isToday)
        XCTAssertFalse(today.isYesterday)
        XCTAssertEqual(today.daysAgo, 0)
        XCTAssertEqual(today.relativeString, "Today")

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        XCTAssertTrue(yesterday.isYesterday)
        XCTAssertEqual(yesterday.relativeString, "Yesterday")
    }

    // MARK: - Performance Tests

    func testCategoryLookupPerformance() {
        let bundleIds = [
            "com.microsoft.VSCode",
            "com.apple.Safari",
            "com.tinyspeck.slackmacgap",
            "com.spotify.client",
            "com.unknown.app"
        ]

        measure {
            for _ in 0..<1000 {
                for bundleId in bundleIds {
                    _ = AppCategory.from(bundleId: bundleId)
                }
            }
        }
    }
}
