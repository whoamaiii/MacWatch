import XCTest
@testable import ClarityShared

final class ClarityTests: XCTestCase {

    private func makeTestDatabase() throws -> DatabaseManager {
        try DatabaseManager(path: ":memory:")
    }

    private func createApp(_ repo: AppRepository, bundleId: String, name: String) throws -> App {
        _ = try repo.findOrCreate(bundleId: bundleId, name: name)
        return try XCTUnwrap(repo.get(bundleId: bundleId))
    }

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

    // MARK: - Repository Tests

    func testUniqueAppCountAndMinuteStatsCount() throws {
        let db = try makeTestDatabase()
        let appRepo = AppRepository(db: db)
        let statsRepo = StatsRepository(db: db)

        let app1 = try createApp(appRepo, bundleId: "com.test.app1", name: "App 1")
        let app2 = try createApp(appRepo, bundleId: "com.test.app2", name: "App 2")
        let app1Id = try XCTUnwrap(app1.id)
        let app2Id = try XCTUnwrap(app2.id)

        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 10, minute: 0, second: 0))!
        let t1 = Int64(baseDate.timeIntervalSince1970)
        let t2 = t1 + 60

        try statsRepo.recordMinuteStat(timestamp: t1, appId: app1Id, keystrokes: 1, clicks: 1, activeSeconds: 30)
        try statsRepo.recordMinuteStat(timestamp: t2, appId: app1Id, keystrokes: 2, clicks: 1, activeSeconds: 30)
        try statsRepo.recordMinuteStat(timestamp: t2, appId: app2Id, keystrokes: 3, clicks: 2, activeSeconds: 60)

        let rangeStart = baseDate
        let rangeEnd = baseDate.addingTimeInterval(180)
        XCTAssertEqual(try statsRepo.getUniqueAppCount(from: rangeStart, to: rangeEnd), 2)
        XCTAssertEqual(try statsRepo.getMinuteStatsCount(from: rangeStart, to: rangeEnd), 3)

        let firstMinuteEnd = baseDate.addingTimeInterval(60)
        XCTAssertEqual(try statsRepo.getUniqueAppCount(from: rangeStart, to: firstMinuteEnd), 1)
    }

    func testFirstActivityDateAndHasActivity() throws {
        let db = try makeTestDatabase()
        let appRepo = AppRepository(db: db)
        let statsRepo = StatsRepository(db: db)

        let app = try createApp(appRepo, bundleId: "com.test.app", name: "Test App")
        let appId = try XCTUnwrap(app.id)

        let calendar = Calendar.current
        let activityDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 20, hour: 9, minute: 15, second: 0))!
        let timestamp = Int64(activityDate.timeIntervalSince1970)
        try statsRepo.recordMinuteStat(timestamp: timestamp, appId: appId, keystrokes: 5, clicks: 2, activeSeconds: 60)

        let start = calendar.startOfDay(for: activityDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let firstActivity = try statsRepo.getFirstActivityDate(from: start, to: end)
        XCTAssertEqual(firstActivity?.timeIntervalSince1970, TimeInterval(timestamp))
        XCTAssertTrue(try statsRepo.hasActivity(on: activityDate))

        let nextDay = calendar.date(byAdding: .day, value: 1, to: activityDate)!
        XCTAssertFalse(try statsRepo.hasActivity(on: nextDay))
    }

    func testAppUsageTotals() throws {
        let db = try makeTestDatabase()
        let appRepo = AppRepository(db: db)
        let statsRepo = StatsRepository(db: db)

        let app = try createApp(appRepo, bundleId: "com.test.app", name: "Test App")
        let appId = try XCTUnwrap(app.id)

        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 14, minute: 0, second: 0))!
        let t1 = Int64(baseDate.timeIntervalSince1970)
        let t2 = t1 + 60

        try statsRepo.recordMinuteStat(timestamp: t1, appId: appId, keystrokes: 4, clicks: 1, activeSeconds: 30)
        try statsRepo.recordMinuteStat(timestamp: t2, appId: appId, keystrokes: 6, clicks: 3, activeSeconds: 45)

        let totals = try statsRepo.getAppUsageTotals(appId: appId, from: baseDate, to: baseDate.addingTimeInterval(120))
        XCTAssertEqual(totals.activeSeconds, 75)
        XCTAssertEqual(totals.keystrokes, 10)
        XCTAssertEqual(totals.clicks, 4)
    }

    func testFocusSessionReuseAndPrimaryAppMetrics() throws {
        let db = try makeTestDatabase()
        let appRepo = AppRepository(db: db)
        let statsRepo = StatsRepository(db: db)

        let app1 = try createApp(appRepo, bundleId: "com.test.app1", name: "App 1")
        let app2 = try createApp(appRepo, bundleId: "com.test.app2", name: "App 2")
        let app1Id = try XCTUnwrap(app1.id)
        let app2Id = try XCTUnwrap(app2.id)

        let firstSession = try statsRepo.startFocusSession(primaryAppId: app1Id)
        let secondSession = try statsRepo.startFocusSession(primaryAppId: app2Id)
        XCTAssertEqual(firstSession.id, secondSession.id)
        XCTAssertEqual(firstSession.primaryAppId, app1Id)

        let sessionCount = try db.read { db in
            try FocusSession.fetchCount(db)
        }
        XCTAssertEqual(sessionCount, 1)

        let sessionId = try XCTUnwrap(firstSession.id)
        let baseTimestamp = Int64(firstSession.startTime.timeIntervalSince1970)
        try statsRepo.recordMinuteStat(timestamp: baseTimestamp, appId: app1Id, keystrokes: 10, clicks: 5, activeSeconds: 60)
        try statsRepo.recordMinuteStat(timestamp: baseTimestamp, appId: app2Id, keystrokes: 99, clicks: 99, activeSeconds: 60)

        let endedSession = try XCTUnwrap(statsRepo.endFocusSession(id: sessionId))
        XCTAssertEqual(endedSession.keystrokes, 10)
        XCTAssertEqual(endedSession.clicks, 5)
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
