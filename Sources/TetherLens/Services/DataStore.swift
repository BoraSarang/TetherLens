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
        let migrator = Self.makeMigrator()
        if let queue = try? DatabaseQueue(path: dbPath.path),
           (try? migrator.migrate(queue)) != nil {
            dbQueue = queue
        } else {
            // 손상된 DB는 백업 후 재생성 (데이터 유실 최소화)
            let backupPath = dbPath.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: dbPath, to: backupPath)
            try? FileManager.default.removeItem(at: dbPath.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: dbPath.appendingPathExtension("shm"))
            dbQueue = try! DatabaseQueue(path: dbPath.path)
            try! migrator.migrate(dbQueue)
        }
    }

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    static func makeMigrator() -> DatabaseMigrator {
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
                guard let idStr = row["id"] as? String,
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
        m.registerMigration("v8_perf_indexes") { db in
            try db.create(index: "idx_usage_log_profile_recorded", on: "usage_log", columns: ["profile_id", "recorded_at"])
            try db.create(index: "idx_session_profile_start", on: "session", columns: ["profile_id", "start_time"])
            try db.execute(sql: """
                PRAGMA foreign_keys = OFF;
                CREATE TABLE usage_log_new (
                    id TEXT PRIMARY KEY,
                    profile_id TEXT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
                    upload_delta INTEGER NOT NULL,
                    download_delta INTEGER NOT NULL,
                    recorded_at TEXT NOT NULL,
                    session_id TEXT REFERENCES session(id) ON DELETE SET NULL
                );
                DELETE FROM usage_log
                WHERE session_id IS NOT NULL
                  AND session_id NOT IN (SELECT id FROM session);
                INSERT INTO usage_log_new (id, profile_id, upload_delta, download_delta, recorded_at, session_id)
                    SELECT id, profile_id, upload_delta, download_delta, recorded_at, session_id FROM usage_log;
                DROP TABLE usage_log;
                ALTER TABLE usage_log_new RENAME TO usage_log;
                CREATE INDEX idx_usage_log_profile ON usage_log(profile_id);
                CREATE INDEX idx_usage_log_recorded ON usage_log(recorded_at);
                CREATE INDEX idx_usage_log_session ON usage_log(session_id);
                CREATE INDEX idx_usage_log_profile_recorded ON usage_log(profile_id, recorded_at);
                PRAGMA foreign_keys = ON;
            """)
        }
        m.registerMigration("v9_connection_type_normalize") { db in
            // 이전 버그(v6~v0.24.0): autoRegisterIfNeeded가 카멜케이스("iOSHotspot")로 덮어써
            // Profile.isHotspot(스네이크케이스 인식)이 false가 되는 어휘 혼재를 정규화한다.
            try db.execute(sql: "UPDATE profile SET connection_type = 'ios_hotspot' WHERE connection_type = 'iOSHotspot'")
            try db.execute(sql: "UPDATE profile SET connection_type = 'android_hotspot' WHERE connection_type = 'AndroidHotspot'")
        }
        m.registerMigration("v10_session_location_source") { db in
            // 지도 GPS/IP 출처 배지용. GPS(기기 위치) vs IP(geo 추정) 구분 메타데이터.
            try db.alter(table: "session") { t in
                t.add(column: "location_source", .text)
            }
        }
        return m
    }
}
