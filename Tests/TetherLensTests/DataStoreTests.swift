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
}
