import Testing
import Foundation
import GRDB
@testable import TetherLens

@Suite struct DataStoreTests {

    private func makeQueue() throws -> DatabaseQueue {
        let q = try DatabaseQueue()
        try DataStore.makeMigrator().migrate(q)
        return q
    }

    @Test func v1부터v8까지_마이그레이션_성공() throws {
        let q = try makeQueue()
        try q.read { db in
            for table in ["profile", "usage_log", "session", "app_traffic_log", "ip_log"] {
                #expect(try db.tableExists(table), "테이블 \(table) 존재")
            }
            let indexes = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='index'")
            for name in ["idx_usage_log_profile", "idx_usage_log_recorded",
                         "idx_session_profile", "idx_session_start",
                         "idx_usage_log_session", "idx_ip_log_profile", "idx_ip_log_ip",
                         "idx_usage_log_profile_recorded", "idx_session_profile_start",
                         "idx_app_traffic_name", "idx_app_traffic_recorded"] {
                #expect(indexes.contains(name), "인덱스 \(name) 존재")
            }
        }
    }

    @Test func usage_log_세션FK_컬럼_존재() throws {
        let q = try makeQueue()
        try q.read { db in
            let cols = try db.columns(in: "usage_log")
            let names = cols.map(\.name)
            #expect(names.contains("session_id"))
            #expect(names.contains("profile_id"))
        }
    }

    @Test func v10_세션_위치출처_컬럼() throws {
        let q = try makeQueue()
        try q.read { db in
            let cols = try db.columns(in: "session")
            let names = cols.map(\.name)
            #expect(names.contains("location_source"), "v10에서 location_source 추가")
        }
    }

    @Test func v11_롤업테이블_존재() throws {
        let q = try makeQueue()
        try q.read { db in
            for table in ["daily_rollup", "app_daily_rollup", "insight_log"] {
                let exists = (try? db.tableExists(table)) ?? false
                #expect(exists, "테이블 \(table) 존재")
            }
        }
    }

    private func makeQueueUpToV10() throws -> DatabaseQueue {
        let q = try DatabaseQueue()
        try DataStore.makeMigrator().migrate(q, upTo: "v10_session_location_source")
        return q
    }

    @Test func v11_backfill_기존로그_이관() throws {
        let q = try makeQueueUpToV10()
        let pid = UUID()
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        try q.write { db in
            try Profile(id: pid, ssid: "TestSSID", name: "T", quotaGB: nil,
                        connectionType: "wifi", createdAt: now, lastConnected: now).insert(db)
            let sid = UUID()
            try Session(id: sid, profileId: pid, startTime: dayStart,
                        endTime: dayStart.addingTimeInterval(3600),
                        latitude: nil, longitude: nil, locationSource: nil).insert(db)
            try UsageLog(id: UUID(), profileId: pid, uploadDelta: 100, downloadDelta: 200,
                         recordedAt: now, sessionId: sid).insert(db)
            try UsageLog(id: UUID(), profileId: pid, uploadDelta: 50, downloadDelta: 60,
                         recordedAt: now, sessionId: nil).insert(db)
            try AppTrafficLog(id: UUID(), processName: "Safari", uploadBytes: 10,
                              downloadBytes: 20, recordedAt: now).insert(db)
        }
        // v11 실행 (backfill)
        try DataStore.makeMigrator().migrate(q)
        try q.read { db in
            let rolls = try DailyRollup.fetchAll(db)
            #expect(rolls.count == 1, "하루 1행 이관")
            #expect(rolls[0].uploadBytes == 150, "업델타 합산")
            #expect(rolls[0].downloadBytes == 260, "다운델타 합산")
            #expect(rolls[0].sessionCount == 1, "종료 세션 1건")
            #expect(rolls[0].sessionSeconds == 3600, "세션 1시간")
            let appRolls = try AppDailyRollup.fetchAll(db)
            #expect(appRolls.count == 1)
            #expect(appRolls[0].uploadBytes == 10 && appRolls[0].downloadBytes == 20)
        }
    }

    @Test func v11_대조_롤업과원천_일치() throws {
        let q = try makeQueueUpToV10()
        let pid = UUID()
        let now = Date()
        try q.write { db in
            try Profile(id: pid, ssid: "S2", name: "T2", quotaGB: nil,
                        connectionType: "wifi", createdAt: now, lastConnected: now).insert(db)
            for i in 0..<5 {
                try UsageLog(id: UUID(), profileId: pid, uploadDelta: Int64(10 * i),
                             downloadDelta: Int64(20 * i), recordedAt: now, sessionId: nil).insert(db)
            }
        }
        try DataStore.makeMigrator().migrate(q)
        // 원천 직접 집계 vs 롤업 비교 (EXACT 일치)
        let raw: Int64 = try q.read { db in
            try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(upload_delta+download_delta),0) FROM usage_log WHERE profile_id = ?",
                               arguments: [pid]) ?? -1
        }
        let rolled: Int64 = try q.read { db in
            try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(upload_bytes+download_bytes),0) FROM daily_rollup WHERE profile_id = ?",
                               arguments: [pid]) ?? -2
        }
        #expect(raw == 300 && rolled == 300, "원천=\(raw) 롤업=\(rolled)")
    }
}
