import Foundation
import GRDB

final class DataStore: @unchecked Sendable {
    static let shared = DataStore()

    let dbQueue: DatabaseQueue

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("TetherLens/data.sqlite")
        let parent = dbPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        dbQueue = try! DatabaseQueue(path: dbPath.path)
        try! migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_profile") { db in
            try db.create(table: "profile") { t in
                t.column("id", .text).primaryKey()
                t.column("ssid", .text).notNull().unique()
                t.column("name", .text).notNull()
                t.column("quota_gb", .double)
                t.column("created_at", .text).notNull()
                t.column("last_connected", .text).notNull()
            }
        }
        m.registerMigration("v2_usage_log") { db in
            try db.create(table: "usage_log") { t in
                t.column("id", .text).primaryKey()
                t.column("profile_id", .text).notNull().references("profile", onDelete: .cascade)
                t.column("upload_delta", .integer).notNull()
                t.column("download_delta", .integer).notNull()
                t.column("recorded_at", .text).notNull()
            }
            try db.create(index: "idx_usage_log_profile", on: "usage_log", columns: ["profile_id"])
            try db.create(index: "idx_usage_log_recorded", on: "usage_log", columns: ["recorded_at"])
        }
        m.registerMigration("v3_session") { db in
            try db.create(table: "session") { t in
                t.column("id", .text).primaryKey()
                t.column("profile_id", .text).notNull().references("profile", onDelete: .cascade)
                t.column("start_time", .text).notNull()
                t.column("end_time", .text)
            }
            try db.create(index: "idx_session_profile", on: "session", columns: ["profile_id"])
            try db.create(index: "idx_session_start", on: "session", columns: ["start_time"])
        }
        m.registerMigration("v4_app_traffic_log") { db in
            try db.create(table: "app_traffic_log") { t in
                t.column("id", .text).primaryKey()
                t.column("process_name", .text).notNull()
                t.column("upload_bytes", .integer).notNull()
                t.column("download_bytes", .integer).notNull()
                t.column("recorded_at", .text).notNull()
            }
            try db.create(index: "idx_app_traffic_name", on: "app_traffic_log", columns: ["process_name"])
            try db.create(index: "idx_app_traffic_recorded", on: "app_traffic_log", columns: ["recorded_at"])
        }
        m.registerMigration("v5_session_usage_link") { db in
            try db.alter(table: "usage_log") { t in
                t.add(column: "session_id", .text)
            }
            try db.create(index: "idx_usage_log_session", on: "usage_log", columns: ["session_id"])
            try db.alter(table: "session") { t in
                t.add(column: "latitude", .double)
                t.add(column: "longitude", .double)
            }
        }
        m.registerMigration("v6_connection_type") { db in
            try db.alter(table: "profile") { t in
                t.add(column: "connection_type", .text)
            }
            let nullRows = try Row.fetchAll(db, sql: "SELECT id, ssid FROM profile WHERE connection_type IS NULL")
            for row in nullRows {
                guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
                      let ssid = row["ssid"] as? String else { continue }
                let classified = Profile.classifiedConnectionType(ssid: ssid)
                try db.execute(sql: "UPDATE profile SET connection_type = ? WHERE id = ?", arguments: [classified, idStr])
            }
        }
        m.registerMigration("v7_ip_log") { db in
            try db.create(table: "ip_log") { t in
                t.column("id", .text).primaryKey()
                t.column("profile_id", .text).notNull().references("profile", onDelete: .cascade)
                t.column("ip_address", .text).notNull()
                t.column("country", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("first_seen_at", .text).notNull()
                t.column("last_seen_at", .text).notNull()
            }
            try db.create(index: "idx_ip_log_profile", on: "ip_log", columns: ["profile_id"])
            try db.create(index: "idx_ip_log_ip", on: "ip_log", columns: ["ip_address"])
        }
        return m
    }
}
