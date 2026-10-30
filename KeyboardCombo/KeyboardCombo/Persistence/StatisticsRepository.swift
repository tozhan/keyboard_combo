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
        selectedStart: Date? = nil,
        excluding excludedKeyCodes: Set<UInt16> = []
    ) throws -> ReportSnapshot {
        let visibleInterval = visibleInterval(for: granularity, anchor: anchor)
        let rows = try database.fetch(from: visibleInterval.start, to: visibleInterval.end)
            .filter { !excludedKeyCodes.contains($0.keyCode) }
        let bucketStarts = timelineBucketStarts(for: granularity, in: visibleInterval)
        let rowsByBucket = Dictionary(grouping: rows) {
            bucketStart(containing: $0.bucketStart, granularity: granularity)
        }

        let timeline = bucketStarts.map {
            TimelinePoint(
                start: $0,
                count: rowsByBucket[$0, default: []].reduce(Int64(0)) { $0 + $1.count }
            )
        }

        let allCodes = Set(KeyCatalog.allKeys.map(\.keyCode))
            .subtracting(excludedKeyCodes)
            .union(rows.map(\.keyCode))
        let displayNames = Dictionary(
            uniqueKeysWithValues: allCodes.map { ($0, KeyCatalog.displayName(for: $0)) }
        )
        let buckets = Dictionary(uniqueKeysWithValues: bucketStarts.map { start in
            let groupedByKey = Dictionary(
                grouping: rowsByBucket[start, default: []],
                by: \.keyCode
            )
            .mapValues { $0.reduce(Int64(0)) { $0 + $1.count } }
            let total = groupedByKey.values.reduce(Int64(0), +)
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
                    ? displayNames[$0.keyCode, default: ""] < displayNames[$1.keyCode, default: ""]
                    : $0.count > $1.count
            }
            let interval = DateInterval(
                start: start,
                end: calendar.date(
                    byAdding: granularity.calendarComponent,
                    value: 1,
                    to: start
                ) ?? visibleInterval.end
            )
            return (start, ReportBucket(interval: interval, keyStatistics: keyStatistics))
        })

        let desiredStart = selectedStart
            .map { bucketStart(containing: $0, granularity: granularity) }
            ?? defaultSelectedStart(for: granularity, visibleInterval: visibleInterval)
        let resolvedSelectedStart = buckets[desiredStart] == nil
            ? defaultSelectedStart(for: granularity, visibleInterval: visibleInterval)
            : desiredStart

        return ReportSnapshot(
            visibleInterval: visibleInterval,
            timeline: timeline,
            buckets: buckets,
            selectedBucketStart: resolvedSelectedStart
        )
    }

    func totalAndTopKeys(
        in interval: DateInterval,
        limit: Int = 5,
        excluding excludedKeyCodes: Set<UInt16> = []
    ) throws -> (Int64, [KeyStatistic]) {
        let rows = try database.fetch(from: interval.start, to: interval.end)
            .filter { !excludedKeyCodes.contains($0.keyCode) }
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
