import Foundation
import XCTest
@testable import KeyboardCombo

final class KeyAggregationTests: XCTestCase {
    func testRecordsCountsAndExcludesAutoRepeatByDefault() async throws {
        let database = try makeDatabase()
        let aggregator = KeyAggregationActor(database: database, flushInterval: .seconds(3_600))
        let date = makeDate(year: 2026, month: 9, day: 1, hour: 10, minute: 5)

        await aggregator.record(
            KeyPress(keyCode: 0, occurredAt: date, isAutoRepeat: false),
            includeAutoRepeat: false
        )
        await aggregator.record(
            KeyPress(keyCode: 0, occurredAt: date, isAutoRepeat: false),
            includeAutoRepeat: false
        )
        await aggregator.record(
            KeyPress(keyCode: 0, occurredAt: date, isAutoRepeat: true),
            includeAutoRepeat: false
        )
        await aggregator.flush()

        let rows = try database.fetch(
            from: date.addingTimeInterval(-3_600),
            to: date.addingTimeInterval(3_600)
        )
        XCTAssertEqual(rows, [
            HourlyKeyCount(
                bucketStart: KeyAggregationActor.utcHourStart(for: date),
                keyCode: 0,
                count: 2
            )
        ])
    }

    func testCrossingHourFlushesBothBuckets() async throws {
        let database = try makeDatabase()
        let aggregator = KeyAggregationActor(database: database, flushInterval: .seconds(3_600))
        let first = makeDate(year: 2026, month: 9, day: 1, hour: 10, minute: 59)
        let second = makeDate(year: 2026, month: 9, day: 1, hour: 11)

        await aggregator.record(
            KeyPress(keyCode: 1, occurredAt: first, isAutoRepeat: false),
            includeAutoRepeat: false
        )
        await aggregator.record(
            KeyPress(keyCode: 1, occurredAt: second, isAutoRepeat: false),
            includeAutoRepeat: false
        )
        await aggregator.flush()

        let rows = try database.fetch(
            from: KeyAggregationActor.utcHourStart(for: first),
            to: second.addingTimeInterval(3_600)
        )
        XCTAssertEqual(rows.map(\.count), [1, 1])
        XCTAssertEqual(Set(rows.map(\.bucketStart)).count, 2)
    }

    func testModifierTrackerCountsOnlyPressEdges() {
        var tracker = ModifierPressTracker()
        let now = Date.now

        XCTAssertTrue(tracker.shouldCount(keyCode: 56, at: now))
        XCTAssertFalse(tracker.shouldCount(keyCode: 56, at: now))
        XCTAssertTrue(tracker.shouldCount(keyCode: 56, at: now))
        XCTAssertFalse(tracker.shouldCount(keyCode: 0, at: now))
    }

    private func makeDatabase() throws -> AppDatabase {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
            .path
        return try AppDatabase(path: path)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
