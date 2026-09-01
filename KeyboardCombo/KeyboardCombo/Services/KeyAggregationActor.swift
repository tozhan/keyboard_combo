import Foundation

actor KeyAggregationActor {
    private struct BucketKey: Hashable {
        let bucketStart: Date
        let keyCode: UInt16
    }

    private let database: AppDatabase
    private let flushInterval: Duration
    private var pending: [BucketKey: Int64] = [:]
    private var flushTask: Task<Void, Never>?

    init(database: AppDatabase, flushInterval: Duration = .seconds(10)) {
        self.database = database
        self.flushInterval = flushInterval
    }

    func start() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self, flushInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: flushInterval)
                guard !Task.isCancelled else { break }
                await self?.flush()
            }
        }
    }

    func record(_ press: KeyPress, includeAutoRepeat: Bool) async {
        guard includeAutoRepeat || !press.isAutoRepeat else { return }
        let bucketStart = Self.utcHourStart(for: press.occurredAt)

        if pending.keys.contains(where: { $0.bucketStart != bucketStart }) {
            await flush()
        }

        let key = BucketKey(bucketStart: bucketStart, keyCode: press.keyCode)
        pending[key, default: 0] += 1
    }

    func flush() async {
        guard !pending.isEmpty else { return }
        let batch = pending.map {
            HourlyKeyCount(bucketStart: $0.key.bucketStart, keyCode: $0.key.keyCode, count: $0.value)
        }
        pending.removeAll(keepingCapacity: true)

        do {
            try database.add(batch)
        } catch {
            for item in batch {
                let key = BucketKey(bucketStart: item.bucketStart, keyCode: item.keyCode)
                pending[key, default: 0] += item.count
            }
        }
    }

    func clear() async {
        pending.removeAll()
    }

    func stop() async {
        flushTask?.cancel()
        flushTask = nil
        await flush()
    }

    static func utcHourStart(for date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: floor(seconds / 3_600) * 3_600)
    }
}
