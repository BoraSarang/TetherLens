import Foundation
import GRDB

/// 인사이트 종류 (v0.34). UI는 kind별 문구를 조합한다 — 엔진은 수치만 반환.
enum InsightKind: String, Codable {
    case pace           // 한도 소진 예측 (오늘 페이스)
    case topOffender    // 오늘 소모 주범 앱
    case anomaly        // 평소 대비 급증
    case sessionEff     // 시간당 소모 1위 세션
}

/// UI에 구애받지 않는 인사이트 데이터. 조용할수록 좋은 지표는 해당 없음(nil/빈 배열).
struct Insight: Identifiable, Equatable {
    let id = UUID()
    let kind: InsightKind
    var profileName: String?
    var appName: String?
    var ratio: Double?          // pace: 소진율, anomaly: 배율, offender: 점유율
    var bytes: Int64?           // 관련 바이트
    var date: Date?             // pace: 예상 소진 시각
    var extra: String?          // sessionEff: 세션 식별자 등

    static func == (lhs: Insight, rhs: Insight) -> Bool {
        lhs.kind == rhs.kind && lhs.profileName == rhs.profileName
            && lhs.appName == rhs.appName && lhs.ratio == rhs.ratio
            && lhs.bytes == rhs.bytes
    }
}

struct DayBucket: Identifiable, Equatable {
    var id: String { day }
    let day: String  // yyyy-MM-dd
    let date: Date
    let upload: Int64
    let download: Int64
    var total: Int64 { upload + download }
}

struct TopAppEntry: Equatable {
    let name: String
    let total: Int64
}

struct StatsSnapshot {
    let insights: [Insight]
    let buckets: [DayBucket]
    let topApps: [TopAppEntry]
    let totalUpload: Int64
    let totalDownload: Int64
    let generatedAt = Date()
}

/// 인사이트 통계 단일 진입점 (v0.34). rollup 기반 고속 집계 + 순수 규칙 함수.
final class StatsEngine: @unchecked Sendable {
    static let shared = StatsEngine()

    private let db: DatabaseQueue
    private let profiles: ProfileManager

    init(dbQueue: DatabaseQueue? = nil) {
        let q = dbQueue ?? DataStore.shared.dbQueue
        self.db = q
        self.profiles = ProfileManager(db: q)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Rollup 증분 갱신

    /// 최근 2일 재계산 + 과거 누락분 삽입. recordUsage 핫패스에는 쓰기 추가 없음.
    func refreshRollups() {
        try! db.write { db in
            try db.execute(sql: """
                INSERT OR IGNORE INTO daily_rollup (day, profile_id, upload_bytes, download_bytes)
                SELECT DATE(recorded_at, 'localtime'), profile_id,
                       COALESCE(SUM(upload_delta), 0), COALESCE(SUM(download_delta), 0)
                FROM usage_log
                WHERE DATE(recorded_at, 'localtime') < DATE('now', 'localtime', '-1 day')
                GROUP BY 1, 2;
                """)
            try db.execute(sql: """
                DELETE FROM daily_rollup WHERE day >= DATE('now', 'localtime', '-1 day');
                INSERT INTO daily_rollup (day, profile_id, upload_bytes, download_bytes)
                SELECT DATE(recorded_at, 'localtime'), profile_id,
                       COALESCE(SUM(upload_delta), 0), COALESCE(SUM(download_delta), 0)
                FROM usage_log
                WHERE DATE(recorded_at, 'localtime') >= DATE('now', 'localtime', '-1 day')
                GROUP BY 1, 2;
                UPDATE daily_rollup AS r SET
                    session_count = (SELECT COUNT(*) FROM session s
                        WHERE s.profile_id = r.profile_id AND s.end_time IS NOT NULL
                          AND DATE(s.start_time, 'localtime') = r.day),
                    session_seconds = (SELECT COALESCE(SUM(CAST(ROUND(
                        (julianday(s.end_time) - julianday(s.start_time)) * 86400) AS INTEGER)), 0)
                        FROM session s
                        WHERE s.profile_id = r.profile_id AND s.end_time IS NOT NULL
                          AND DATE(s.start_time, 'localtime') = r.day)
                WHERE r.day >= DATE('now', 'localtime', '-1 day');
                """)
            try db.execute(sql: """
                INSERT OR IGNORE INTO app_daily_rollup (day, process_name, upload_bytes, download_bytes)
                SELECT DATE(recorded_at, 'localtime'), process_name,
                       COALESCE(SUM(upload_bytes), 0), COALESCE(SUM(download_bytes), 0)
                FROM app_traffic_log
                WHERE DATE(recorded_at, 'localtime') < DATE('now', 'localtime', '-1 day')
                GROUP BY 1, 2;
                DELETE FROM app_daily_rollup WHERE day >= DATE('now', 'localtime', '-1 day');
                INSERT INTO app_daily_rollup (day, process_name, upload_bytes, download_bytes)
                SELECT DATE(recorded_at, 'localtime'), process_name,
                       COALESCE(SUM(upload_bytes), 0), COALESCE(SUM(download_bytes), 0)
                FROM app_traffic_log
                WHERE DATE(recorded_at, 'localtime') >= DATE('now', 'localtime', '-1 day')
                GROUP BY 1, 2;
                """)
        }
    }

    // MARK: - Snapshot

    /// (프로필, 기간) → 스냅샷 단일 진입점. 호출 전 refreshRollups() 권장.
    func snapshot(profileIds: [UUID], days: Int) -> StatsSnapshot {
        let buckets = dayBuckets(profileIds: profileIds, days: days)
        let totalUp = buckets.reduce(0) { $0 + $1.upload }
        let totalDn = buckets.reduce(0) { $0 + $1.download }
        let topApps = topApps(days: days, limit: 5)
        var insights: [Insight] = []
        insights += paceInsights(profileIds: profileIds)
        if let offender = topOffenderInsight(days: 1) { insights.append(offender) }
        if let anomaly = anomalyInsight(profileIds: profileIds) { insights.append(anomaly) }
        if let eff = sessionEffInsight(profileIds: profileIds, days: min(days, 7)) { insights.append(eff) }
        return StatsSnapshot(insights: insights, buckets: buckets, topApps: topApps,
                             totalUpload: totalUp, totalDownload: totalDn)
    }

    // MARK: - Rollup 조회

    func dayBuckets(profileIds: [UUID], days: Int) -> [DayBucket] {
        guard !profileIds.isEmpty else { return [] }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let placeholders = profileIds.map { _ in "?" }.joined(separator: ",")
        let rows = try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT day, COALESCE(SUM(upload_bytes),0) AS up, COALESCE(SUM(download_bytes),0) AS dn
                FROM daily_rollup
                WHERE profile_id IN (\(placeholders)) AND day >= DATE(?, 'unixepoch', 'localtime')
                GROUP BY day ORDER BY day ASC
            """, arguments: StatementArguments(profileIds.map { $0 as DatabaseValueConvertible } + [cutoff.timeIntervalSince1970]))
        }
        return rows.compactMap { row in
            guard let day = row["day"] as? String,
                  let up = row["up"] as? Int64,
                  let dn = row["dn"] as? Int64,
                  let date = Self.dayFormatter.date(from: day) else { return nil }
            return DayBucket(day: day, date: date, upload: up, download: dn)
        }
    }

    func topApps(days: Int, limit: Int = 5) -> [TopAppEntry] {
        let cutoffDay = Self.dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!)
        let rows = try! db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT process_name, SUM(upload_bytes + download_bytes) AS total
                FROM app_daily_rollup WHERE day >= ?
                GROUP BY process_name ORDER BY total DESC LIMIT ?
            """, arguments: [cutoffDay, limit * 2])
        }
        return rows.compactMap { row -> TopAppEntry? in
            guard let name = row["process_name"] as? String,
                  let total = row["total"] as? Int64,
                  !SystemProcesses.set.contains(name) else { return nil }
            return TopAppEntry(name: name, total: total)
        }.prefix(limit).map { $0 }
    }

    // MARK: - 인사이트 규칙 (순수 함수 — 단위 테스트 대상)

    /// 오늘 페이스로 자정 전 한도 소진 예상 시각. 자정 이후 소진이면 nil.
    static func projectedExhaustion(usedToday: Int64, quotaBytes: Int64, now: Date = Date()) -> Date? {
        guard quotaBytes > 0, usedToday >= 0 else { return nil }
        if usedToday >= quotaBytes { return now }  // 이미 초과
        let startOfDay = Calendar.current.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(startOfDay)
        guard elapsed > 900, usedToday > 0 else { return nil }  // 15분 미만은 잡음
        let rate = Double(usedToday) / elapsed
        let remaining = Double(quotaBytes - usedToday)
        let exhaustion = now.addingTimeInterval(remaining / rate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return exhaustion < endOfDay ? exhaustion : nil
    }

    static func anomalyTriggered(today: Int64, priorDailyAverage: Double) -> Double? {
        guard priorDailyAverage >= 10_000_000, today > 0 else { return nil }  // baseline 10MB 미만 잡음 제외
        let ratio = Double(today) / priorDailyAverage
        return ratio >= 2.0 ? ratio : nil
    }

    func paceInsights(profileIds: [UUID]) -> [Insight] {
        profileIds.compactMap { pid in
            guard let p = profiles.getProfile(id: pid),
                  let quota = p.quotaGB, quota > 0 else { return nil }
            let used = profiles.getTodayUsage(profileId: pid)
            let usedTotal = used.upload + used.download
            let quotaBytes = Int64(quota * 1_000_000_000)
            guard let exhaustion = Self.projectedExhaustion(usedToday: usedTotal, quotaBytes: quotaBytes) else { return nil }
            return Insight(kind: .pace, profileName: p.name,
                           ratio: min(Double(usedTotal) / Double(quotaBytes), 9.99),
                           bytes: usedTotal, date: exhaustion)
        }
    }

    func topOffenderInsight(days: Int) -> Insight? {
        let apps = topApps(days: days, limit: 1)
        guard let top = apps.first else { return nil }
        let total = topApps(days: days, limit: 50).reduce(0) { $0 + $1.total }
        guard total >= 50_000_000 else { return nil }  // 50MB 미만 잡음 제외
        let share = Double(top.total) / Double(total)
        guard share >= 0.4 else { return nil }
        return Insight(kind: .topOffender, appName: top.name, ratio: share, bytes: top.total)
    }

    func anomalyInsight(profileIds: [UUID]) -> Insight? {
        let priorCutoff = Self.dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: -8, to: Date())!)
        guard !profileIds.isEmpty else { return nil }
        let placeholders = profileIds.map { _ in "?" }.joined(separator: ",")
        let args: [DatabaseValueConvertible] = profileIds.map { $0 as DatabaseValueConvertible }
        let todayTotal: Int64 = (try? db.read { db in
            try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(upload_bytes + download_bytes), 0) FROM daily_rollup
                WHERE profile_id IN (\(placeholders)) AND day = DATE('now', 'localtime')
            """, arguments: StatementArguments(args)) ?? 0
        }) ?? 0
        let priorAvg: Double = (try? db.read { db in
            try Double.fetchOne(db, sql: """
                SELECT COALESCE(SUM(upload_bytes + download_bytes), 0) / 7.0 FROM daily_rollup
                WHERE profile_id IN (\(placeholders)) AND day >= ? AND day < DATE('now', 'localtime')
            """, arguments: StatementArguments(args + [priorCutoff])) ?? 0
        }) ?? 0
        guard let ratio = Self.anomalyTriggered(today: todayTotal, priorDailyAverage: priorAvg) else { return nil }
        return Insight(kind: .anomaly, ratio: ratio, bytes: todayTotal)
    }

    func sessionEffInsight(profileIds: [UUID], days: Int) -> Insight? {
        var best: (name: String, bytesPerHour: Double, bytes: Int64)? = nil
        for pid in profileIds {
            guard let p = profiles.getProfile(id: pid) else { continue }
            for s in profiles.getSessions(profileId: pid, days: days) {
                guard let end = s.endTime else { continue }
                let hours = end.timeIntervalSince(s.startTime) / 3600
                guard hours >= (1.0 / 6.0) else { continue }  // 10분 미만 제외
                let u = profiles.getSessionUsage(session: s)
                let bytes = u.0 + u.1
                let bph = Double(bytes) / hours
                guard bph >= 100_000_000 else { continue }  // 100MB/h 미만 제외
                if best == nil || bph > best!.bytesPerHour {
                    best = (p.name, bph, bytes)
                }
            }
        }
        guard let b = best else { return nil }
        return Insight(kind: .sessionEff, profileName: b.name, ratio: b.bytesPerHour, bytes: b.bytes)
    }
}
