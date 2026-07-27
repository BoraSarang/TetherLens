import Foundation
import GRDB

final class ProfileManager: @unchecked Sendable {
    static let shared = ProfileManager()

    private var db: DatabaseQueue { DataStore.shared.dbQueue }

    private var cachedSSID: String?
    private var cachedProfileResult: Profile?
    private var cachedProfileTime: Date?
    private var cachedUsageResult: (upload: Int64, download: Int64)?
    private var cachedUsageProfileId: UUID?
    private var cachedUsageTime: Date?

    private func isCacheValid(_ time: Date?) -> Bool {
        guard let t = time else { return false }
        return Date().timeIntervalSince(t) < 3
    }

    // MARK: - Profile CRUD

    func getAllProfiles() -> [Profile] {
        try! db.read { db in
            try Profile.order(Column("last_connected").desc).fetchAll(db)
        }
    }

    func getProfile(ssid: String) -> Profile? {
        if isCacheValid(cachedProfileTime), cachedSSID == ssid, let result = cachedProfileResult {
            return result
        }
        let result = try! db.read { db in
            try Profile.filter(Column("ssid") == ssid).fetchOne(db)
        }
        cachedSSID = ssid
        cachedProfileResult = result
        cachedProfileTime = Date()
        return result
    }

    func getProfile(id: UUID) -> Profile? {
        try! db.read { db in
            try Profile.fetchOne(db, key: id)
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

    func deleteUsageData(profileId: UUID) {
        try! db.write { db in
            try UsageLog.filter(Column("profile_id") == profileId).deleteAll(db)
        }
        invalidateCache()
    }

    func invalidateCache() {
        cachedProfileTime = Date.distantPast
        cachedUsageTime = Date.distantPast
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
        let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        try! db.write { db in
            try UsageLog.filter(Column("recorded_at") < cutoff).deleteAll(db)
        }
    }

    func getTodayUsage(profileId: UUID) -> (upload: Int64, download: Int64) {
        if isCacheValid(cachedUsageTime), cachedUsageProfileId == profileId, let result = cachedUsageResult {
            return result
        }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let up = try! db.read { db in
            try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(upload_delta), 0) FROM usage_log
                WHERE profile_id = ? AND recorded_at >= ?
            """, arguments: [profileId, startOfToday]) ?? 0
        }
        let dn = try! db.read { db in
            try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(download_delta), 0) FROM usage_log
                WHERE profile_id = ? AND recorded_at >= ?
            """, arguments: [profileId, startOfToday]) ?? 0
        }
        let result: (upload: Int64, download: Int64) = (up, dn)
        cachedUsageProfileId = profileId
        cachedUsageResult = result
        cachedUsageTime = Date()
        return result
    }

    // MARK: - Usage Report

    struct DailyUsage: Identifiable {
        let id: String
        let date: Date
        let upload: Int64
        let download: Int64
        var total: Int64 { upload + download }
    }

    struct MonthlyUsage: Identifiable {
        let id: String
        let date: Date
        let upload: Int64
        let download: Int64
        var total: Int64 { upload + download }
    }

    struct DailySessionSummary: Identifiable {
        let id: String
        let date: Date
        let sessionCount: Int
        let totalDuration: TimeInterval
    }

    struct MonthlySessionSummary: Identifiable {
        let id: String
        let date: Date
        let sessionCount: Int
        let totalDuration: TimeInterval
    }

    func getDailyUsage(profileId: UUID, days: Int) -> [DailyUsage] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT DATE(recorded_at, 'localtime') AS day,
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

    func getMonthlyUsage(profileId: UUID, months: Int) -> [MonthlyUsage] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        return try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT strftime('%Y-%m', recorded_at, 'localtime') AS month,
                       COALESCE(SUM(upload_delta), 0) AS up,
                       COALESCE(SUM(download_delta), 0) AS dn
                FROM usage_log
                WHERE profile_id = ? AND recorded_at >= ?
                GROUP BY month
                ORDER BY month DESC
            """, arguments: [profileId, cutoff])
            .compactMap { row in
                guard let monthStr = row["month"] as? String,
                      let up = row["up"] as? Int64,
                      let dn = row["dn"] as? Int64,
                      let date = dateFormatter.date(from: monthStr)
                else { return nil }
                return MonthlyUsage(id: monthStr, date: date, upload: up, download: dn)
            }
        }
    }

    func getDailySessionSummary(profileId: UUID, days: Int) -> [DailySessionSummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT DATE(start_time, 'localtime') AS day,
                       COUNT(*) AS cnt,
                       COALESCE(SUM(CASE WHEN end_time IS NOT NULL THEN (julianday(end_time) - julianday(start_time)) * 86400 END), 0) AS dur
                FROM session
                WHERE profile_id = ? AND start_time >= ?
                GROUP BY day
                ORDER BY day DESC
            """, arguments: [profileId, cutoff])
            .compactMap { row in
                guard let dayStr = row["day"] as? String,
                      let cnt = row["cnt"] as? Int64,
                      let dur = row["dur"] as? Double,
                      let date = dateFormatter.date(from: dayStr)
                else { return nil }
                return DailySessionSummary(id: dayStr, date: date, sessionCount: Int(cnt), totalDuration: dur)
            }
        }
    }

    func getMonthlySessionSummary(profileId: UUID, months: Int) -> [MonthlySessionSummary] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        return try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT strftime('%Y-%m', start_time, 'localtime') AS month,
                       COUNT(*) AS cnt,
                       COALESCE(SUM(CASE WHEN end_time IS NOT NULL THEN (julianday(end_time) - julianday(start_time)) * 86400 END), 0) AS dur
                FROM session
                WHERE profile_id = ? AND start_time >= ?
                GROUP BY month
                ORDER BY month DESC
            """, arguments: [profileId, cutoff])
            .compactMap { row in
                guard let monthStr = row["month"] as? String,
                      let cnt = row["cnt"] as? Int64,
                      let dur = row["dur"] as? Double,
                      let date = dateFormatter.date(from: monthStr)
                else { return nil }
                return MonthlySessionSummary(id: monthStr, date: date, sessionCount: Int(cnt), totalDuration: dur)
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

    func endAllActiveSessions() {
        try! db.write { db in
            try Session
                .filter(Column("end_time") == nil)
                .updateAll(db, Column("end_time").set(to: Date()))
        }
    }

    func getAppTrafficLogs(days: Int = 1) -> [(processName: String, uploadBytes: Int64, downloadBytes: Int64)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let rows = try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT process_name, SUM(upload_bytes) AS upload, SUM(download_bytes) AS download
                FROM app_traffic_log
                WHERE recorded_at >= ?
                GROUP BY process_name
                ORDER BY upload + download DESC
            """, arguments: [cutoff])
        }
        return rows.map { row in
            (
                processName: row["process_name"] as! String,
                uploadBytes: row["upload"] as! Int64,
                downloadBytes: row["download"] as! Int64
            )
        }
    }

    func cleanupAppTrafficLogs() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        try! db.write { db in
            try AppTrafficLog.filter(Column("recorded_at") < cutoff).deleteAll(db)
        }
    }
}
