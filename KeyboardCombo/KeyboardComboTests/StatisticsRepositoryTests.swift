import Foundation
import XCTest
@testable import KeyboardCombo

final class StatisticsRepositoryTests: XCTestCase {
    func testHourlySnapshotCalculatesCountsAndPercentages() throws {
        let database = try makeDatabase()
        let calendar = utcCalendar()
        let repository = StatisticsRepository(database: database, calendar: calendar)
        let ten = makeDate(year: 2026, month: 9, day: 1, hour: 10)
        let eleven = makeDate(year: 2026, month: 9, day: 1, hour: 11)
        try database.add([
            HourlyKeyCount(bucketStart: ten, keyCode: 0, count: 75),
            HourlyKeyCount(bucketStart: ten, keyCode: 1, count: 25),
            HourlyKeyCount(bucketStart: eleven, keyCode: 0, count: 10)
        ])

        let snapshot = try repository.snapshot(
            granularity: .hour,
            anchor: ten,
            selectedStart: ten
        )

        XCTAssertEqual(snapshot.timeline.count, 24)
        XCTAssertEqual(snapshot.selectedTotal, 100)
        XCTAssertEqual(snapshot.keyStatistics.first(where: { $0.keyCode == 0 })?.percentage, 0.75)
        XCTAssertEqual(snapshot.keyStatistics.first(where: { $0.keyCode == 1 })?.percentage, 0.25)
        XCTAssertEqual(
            snapshot.keyStatistics.reduce(0) { $0 + $1.percentage },
            1,
            accuracy: 0.000_001
        )
    }

    func testWeekStartsOnMondayAndContainsTwelveBuckets() throws {
        let database = try makeDatabase()
        let calendar = utcCalendar()
        let repository = StatisticsRepository(database: database, calendar: calendar)
        let wednesday = makeDate(year: 2026, month: 9, day: 2, hour: 12)

        let snapshot = try repository.snapshot(
            granularity: .week,
            anchor: wednesday
        )

        XCTAssertEqual(snapshot.timeline.count, 12)
        XCTAssertEqual(calendar.component(.weekday, from: snapshot.timeline[0].start), 2)
        XCTAssertEqual(snapshot.visibleInterval.end, makeDate(year: 2026, month: 9, day: 7))
    }

    func testEmptySnapshotReturnsZeroPercentages() throws {
        let repository = StatisticsRepository(database: try makeDatabase(), calendar: utcCalendar())
        let anchor = makeDate(year: 2024, month: 2, day: 29)

        let snapshot = try repository.snapshot(granularity: .day, anchor: anchor)

        XCTAssertEqual(snapshot.timeline.count, 29)
        XCTAssertEqual(snapshot.selectedTotal, 0)
        XCTAssertTrue(snapshot.keyStatistics.allSatisfy { $0.percentage == 0 })
    }

    func testHourlyTimelineFollowsDaylightSavingBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = 2
        let anchor = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)
        )!
        let repository = StatisticsRepository(database: try makeDatabase(), calendar: calendar)

        let snapshot = try repository.snapshot(granularity: .hour, anchor: anchor)

        XCTAssertEqual(snapshot.timeline.count, 23)
    }

    private func makeDatabase() throws -> AppDatabase {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
        return try AppDatabase(path: path)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0
    ) -> Date {
        utcCalendar().date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
    }
}
