import Foundation

struct KeyPress: Sendable, Equatable {
    let keyCode: UInt16
    let occurredAt: Date
    let isAutoRepeat: Bool
}

struct HourlyKeyCount: Sendable, Equatable {
    let bucketStart: Date
    let keyCode: UInt16
    let count: Int64
}

enum ReportGranularity: String, CaseIterable, Identifiable, Sendable {
    case hour = "小时"
    case day = "天"
    case week = "周"
    case month = "月"

    var id: Self { self }

    var calendarComponent: Calendar.Component {
        switch self {
        case .hour: .hour
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

struct TimelinePoint: Identifiable, Sendable, Equatable {
    let start: Date
    let count: Int64

    var id: Date { start }
}

struct KeyStatistic: Identifiable, Sendable, Equatable {
    let keyCode: UInt16
    let count: Int64
    let percentage: Double

    var id: UInt16 { keyCode }
}

struct ReportBucket: Sendable, Equatable {
    let interval: DateInterval
    let keyStatistics: [KeyStatistic]
}

struct ReportSnapshot: Sendable, Equatable {
    let visibleInterval: DateInterval
    let timeline: [TimelinePoint]
    let buckets: [Date: ReportBucket]
    let selectedBucketStart: Date

    var selectedInterval: DateInterval {
        buckets[selectedBucketStart]?.interval ?? visibleInterval
    }

    var keyStatistics: [KeyStatistic] {
        buckets[selectedBucketStart]?.keyStatistics ?? []
    }

    var selectedTotal: Int64 {
        keyStatistics.reduce(0) { $0 + $1.count }
    }

    func selectingBucket(start: Date) -> ReportSnapshot {
        guard buckets[start] != nil else { return self }
        return ReportSnapshot(
            visibleInterval: visibleInterval,
            timeline: timeline,
            buckets: buckets,
            selectedBucketStart: start
        )
    }
}
