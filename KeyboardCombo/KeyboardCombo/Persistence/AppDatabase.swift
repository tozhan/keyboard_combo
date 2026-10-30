import Foundation
import GRDB

final class AppDatabase: @unchecked Sendable {
    private let writer: any DatabaseWriter

    convenience init() throws {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("KeyboardCombo", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try self.init(path: directory.appendingPathComponent("keyboard-counts.sqlite").path)
    }

    init(path: String) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        writer = try DatabaseQueue(path: path, configuration: configuration)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createHourlyKeyCounts") { db in
            try db.execute(
                sql: """
                    CREATE TABLE hourly_key_counts (
                        bucket_start REAL NOT NULL,
                        key_code INTEGER NOT NULL,
                        count INTEGER NOT NULL CHECK (count > 0),
                        PRIMARY KEY (bucket_start, key_code)
                    ) WITHOUT ROWID
                    """
            )
            try db.execute(
                sql: "CREATE INDEX hourly_key_counts_bucket_idx ON hourly_key_counts(bucket_start)"
            )
        }
        try migrator.migrate(writer)
    }

    func add(_ counts: [HourlyKeyCount]) throws {
        guard !counts.isEmpty else { return }

        try writer.write { db in
            for item in counts where item.count > 0 {
                try db.execute(
                    sql: """
                        INSERT INTO hourly_key_counts (bucket_start, key_code, count)
                        VALUES (?, ?, ?)
                        ON CONFLICT(bucket_start, key_code)
                        DO UPDATE SET count = count + excluded.count
                        """,
                    arguments: [item.bucketStart.timeIntervalSince1970, item.keyCode, item.count]
                )
            }
        }
    }

    func fetch(from start: Date, to end: Date) throws -> [HourlyKeyCount] {
        try writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT bucket_start, key_code, count
                    FROM hourly_key_counts
                    WHERE bucket_start >= ? AND bucket_start < ?
                    ORDER BY bucket_start
                    """,
                arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970]
            )

            return rows.map { row in
                HourlyKeyCount(
                    bucketStart: Date(timeIntervalSince1970: row["bucket_start"]),
                    keyCode: UInt16(row["key_code"] as Int),
                    count: row["count"]
                )
            }
        }
    }

    func deleteAll() throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM hourly_key_counts")
        }
    }
}
