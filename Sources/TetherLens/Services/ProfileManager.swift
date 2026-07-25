import Foundation
import GRDB

final class ProfileManager: @unchecked Sendable {
    static let shared = ProfileManager()

    private var db: DatabaseQueue { DataStore.shared.dbQueue }

    // MARK: - Profile CRUD

    func getAllProfiles() -> [Profile] {
        try! db.read { db in
            try Profile.order(Column("last_connected").desc).fetchAll(db)
        }
    }

    func getProfile(id: UUID) -> Profile? {
        try! db.read { db in
            try Profile.fetchOne(db, key: id)
        }
    }

    func getProfile(ssid: String) -> Profile? {
        try! db.read { db in
            try Profile.filter(Column("ssid") == ssid).fetchOne(db)
        }
    }

    func saveProfile(_ profile: Profile) {
        try! db.write { db in
            try profile.save(db)
        }
    }

    func deleteProfile(id: UUID) {
        try! db.write { db in
            try UsageLog.filter(Column("profile_id") == id).deleteAll(db)
            try Profile.filter(Column("id") == id).deleteAll(db)
        }
    }

    @discardableResult
    func autoRegisterIfNeeded(ssid: String) -> Profile {
        if let existing = getProfile(ssid: ssid) {
            var updated = existing
            updated.lastConnected = Date()
            saveProfile(updated)
            return updated
        }
        let profile = Profile(
            id: UUID(),
            ssid: ssid,
            name: ssid,
            quotaGB: nil,
            createdAt: Date(),
            lastConnected: Date()
        )
        saveProfile(profile)
        return profile
    }

    // MARK: - Usage Recording

    private var lastCumulativeUpload: Int64?
    private var lastCumulativeDownload: Int64?
    private var lastRecordProfileId: UUID?

    func recordUsage(totalUpload: Int64, totalDownload: Int64, profileId: UUID) {
        guard let lastUp = lastCumulativeUpload,
              let lastDn = lastCumulativeDownload,
              lastRecordProfileId == profileId else {
            lastCumulativeUpload = totalUpload
            lastCumulativeDownload = totalDownload
            lastRecordProfileId = profileId
            return
        }

        let upDelta = totalUpload - lastUp
        let dnDelta = totalDownload - lastDn

        if upDelta < 0 || dnDelta < 0 {
            lastCumulativeUpload = totalUpload
            lastCumulativeDownload = totalDownload
            return
        }

        if upDelta > 0 || dnDelta > 0 {
            let log = UsageLog(
                id: UUID(),
                profileId: profileId,
                uploadDelta: upDelta,
                downloadDelta: dnDelta,
                recordedAt: Date()
            )
            try! db.write { db in
                try log.insert(db)
            }
        }

        lastCumulativeUpload = totalUpload
        lastCumulativeDownload = totalDownload
    }

    func getUsageLogs(profileId: UUID, days: Int = 7) -> [UsageLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return try! db.read { db in
            try UsageLog
                .filter(Column("profile_id") == profileId)
                .filter(Column("recorded_at") >= cutoff)
                .order(Column("recorded_at").asc)
                .fetchAll(db)
        }
    }

    func cleanupOldLogs() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        try! db.write { db in
            try UsageLog.filter(Column("recorded_at") < cutoff).deleteAll(db)
        }
    }

    func getTodayUsage(profileId: UUID) -> (upload: Int64, download: Int64) {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return try! db.read { db in
            let up = try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(upload_delta), 0) FROM usage_log
                WHERE profile_id = ? AND recorded_at >= ?
            """, arguments: [profileId, startOfToday]) ?? 0
            let dn = try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(download_delta), 0) FROM usage_log
                WHERE profile_id = ? AND recorded_at >= ?
            """, arguments: [profileId, startOfToday]) ?? 0
            return (up, dn)
        }
    }

    // MARK: - Usage Report

    struct DailyUsage: Identifiable {
        let id: String
        let date: Date
        let upload: Int64
        let download: Int64
        var total: Int64 { upload + download }
    }

    func getDailyUsage(profileId: UUID, days: Int) -> [DailyUsage] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT DATE(recorded_at) AS day,
                       COALESCE(SUM(upload_delta), 0) AS up,
                       COALESCE(SUM(download_delta), 0) AS dn
                FROM usage_log
                WHERE profile_id = ? AND recorded_at >= ?
                GROUP BY day
                ORDER BY day DESC
            """, arguments: [profileId, cutoff])
            .compactMap { row in
                guard let dayStr = row["day"] as? String,
                      let up = row["up"] as? Int64,
                      let dn = row["dn"] as? Int64,
                      let date = dateFormatter.date(from: dayStr)
                else { return nil }
                return DailyUsage(id: dayStr, date: date, upload: up, download: dn)
            }
        }
    }

    func getTotalUsage(profileId: UUID) -> (upload: Int64, download: Int64) {
        try! db.read { db in
            let up = try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(upload_delta), 0) FROM usage_log WHERE profile_id = ?
            """, arguments: [profileId]) ?? 0
            let dn = try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(download_delta), 0) FROM usage_log WHERE profile_id = ?
            """, arguments: [profileId]) ?? 0
            return (up, dn)
        }
    }

    // MARK: - Session Tracking

    func startSession(profileId: UUID) -> Session {
        let session = Session(id: UUID(), profileId: profileId, startTime: Date(), endTime: nil)
        try! db.write { db in
            try session.insert(db)
        }
        return session
    }

    func endSession(_ session: Session) {
        var updated = session
        updated.endTime = Date()
        try! db.write { db in
            try updated.save(db)
        }
    }

    func getActiveSession(profileId: UUID) -> Session? {
        try! db.read { db in
            try Session
                .filter(Column("profile_id") == profileId)
                .filter(Column("end_time") == nil)
                .fetchOne(db)
        }
    }

    func getSessions(profileId: UUID, days: Int) -> [Session] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return try! db.read { db in
            try Session
                .filter(Column("profile_id") == profileId)
                .filter(Column("start_time") >= cutoff)
                .order(Column("start_time").desc)
                .fetchAll(db)
        }
    }

    func endAllActiveSessions(profileId: UUID) {
        let active = try! db.read { db in
            try Session
                .filter(Column("profile_id") == profileId)
                .filter(Column("end_time") == nil)
                .fetchAll(db)
        }
        try! db.write { db in
            for var s in active {
                s.endTime = Date()
                try s.save(db)
            }
        }
    }
}
