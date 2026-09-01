import Foundation

final class StatisticsRepository: @unchecked Sendable {
    private let database: AppDatabase
    private var calendar: Calendar

    init(database: AppDatabase, calendar: Calendar = .autoupdatingCurrent) {
        self.database = database
        self.calendar = calendar
        self.calendar.firstWeekday = 2
    }

    func snapshot(
        granularity: ReportGranularity,
        anchor: Date,
        selectedStart: Date? = nil
    ) throws -> ReportSnapshot {
        let visibleInterval = visibleInterval(for: granularity, anchor: anchor)
        let rows = try database.fetch(from: visibleInterval.start, to: visibleInterval.end)
        let bucketStarts = timelineBucketStarts(for: granularity, in: visibleInterval)
        let countsByBucket = Dictionary(grouping: rows) {
            bucketStart(containing: $0.bucketStart, granularity: granularity)
        }.mapValues { groupedRows in
            groupedRows.reduce(Int64(0)) { $0 + $1.count }
        }

        let timeline = bucketStarts.map {
            TimelinePoint(start: $0, count: countsByBucket[$0, default: 0])
        }

        let desiredStart = selectedStart
            .map { bucketStart(containing: $0, granularity: granularity) }
            ?? defaultSelectedStart(for: granularity, visibleInterval: visibleInterval)
        let selectedInterval = DateInterval(
            start: desiredStart,
            end: calendar.date(
                byAdding: granularity.calendarComponent,
                value: 1,
                to: desiredStart
            ) ?? visibleInterval.end
        )

        let selectedRows = rows.filter {
            $0.bucketStart >= selectedInterval.start && $0.bucketStart < selectedInterval.end
        }
        let groupedByKey = Dictionary(grouping: selectedRows, by: \.keyCode)
            .mapValues { $0.reduce(Int64(0)) { $0 + $1.count } }
        let total = groupedByKey.values.reduce(Int64(0), +)
        let allCodes = Set(KeyCatalog.allKeys.map(\.keyCode)).union(groupedByKey.keys)
        let keyStatistics = allCodes.map { keyCode in
            let count = groupedByKey[keyCode, default: 0]
            return KeyStatistic(
                keyCode: keyCode,
                count: count,
                percentage: total == 0 ? 0 : Double(count) / Double(total)
            )
        }
        .sorted {
            $0.count == $1.count
                ? KeyCatalog.displayName(for: $0.keyCode) < KeyCatalog.displayName(for: $1.keyCode)
                : $0.count > $1.count
        }

        return ReportSnapshot(
            visibleInterval: visibleInterval,
            selectedInterval: selectedInterval,
            timeline: timeline,
            keyStatistics: keyStatistics
        )
    }

    func totalAndTopKeys(in interval: DateInterval, limit: Int = 5) throws -> (Int64, [KeyStatistic]) {
        let rows = try database.fetch(from: interval.start, to: interval.end)
        let counts = Dictionary(grouping: rows, by: \.keyCode)
            .mapValues { $0.reduce(Int64(0)) { $0 + $1.count } }
        let total = counts.values.reduce(Int64(0), +)
        let top = counts.map { keyCode, count in
            KeyStatistic(
                keyCode: keyCode,
                count: count,
                percentage: total == 0 ? 0 : Double(count) / Double(total)
            )
        }
        .sorted { $0.count > $1.count }
        .prefix(limit)

        return (total, Array(top))
    }

    func todayInterval(for date: Date = .now) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        return DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 1, to: start) ?? date
        )
    }

    func deleteAll() throws {
        try database.deleteAll()
    }

    private func visibleInterval(for granularity: ReportGranularity, anchor: Date) -> DateInterval {
        let start: Date
        let end: Date

        switch granularity {
        case .hour:
            start = calendar.startOfDay(for: anchor)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? anchor
        case .day:
            start = calendar.date(
                from: calendar.dateComponents([.year, .month], from: anchor)
            ) ?? anchor
            end = calendar.date(byAdding: .month, value: 1, to: start) ?? anchor
        case .week:
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: anchor)
                ?? DateInterval(start: anchor, duration: 7 * 86_400)
            start = calendar.date(byAdding: .weekOfYear, value: -11, to: currentWeek.start)
                ?? currentWeek.start
            end = currentWeek.end
        case .month:
            start = calendar.date(from: calendar.dateComponents([.year], from: anchor)) ?? anchor
            end = calendar.date(byAdding: .year, value: 1, to: start) ?? anchor
        }
        return DateInterval(start: start, end: end)
    }

    private func timelineBucketStarts(
        for granularity: ReportGranularity,
        in interval: DateInterval
    ) -> [Date] {
        var result: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(
                byAdding: granularity.calendarComponent,
                value: 1,
                to: cursor
            ), next > cursor else {
                break
            }
            cursor = next
        }
        return result
    }

    private func bucketStart(containing date: Date, granularity: ReportGranularity) -> Date {
        switch granularity {
        case .hour:
            calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .day:
            calendar.startOfDay(for: date)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month:
            calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }
    }

    private func defaultSelectedStart(
        for granularity: ReportGranularity,
        visibleInterval: DateInterval
    ) -> Date {
        let now = Date.now
        if visibleInterval.contains(now) {
            return bucketStart(containing: now, granularity: granularity)
        }
        let lastMoment = visibleInterval.end.addingTimeInterval(-1)
        return bucketStart(containing: lastMoment, granularity: granularity)
    }
}
