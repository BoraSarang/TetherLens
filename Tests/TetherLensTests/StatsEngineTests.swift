import Testing
import Foundation
import GRDB
@testable import TetherLens

@Suite struct StatsEngineTests {

    private func makeEngine() throws -> (DatabaseQueue, ProfileManager, StatsEngine) {
        let q = try DatabaseQueue()
        try DataStore.makeMigrator().migrate(q)
        return (q, ProfileManager(db: q), StatsEngine(dbQueue: q))
    }

    private func noon(daysAgo: Int) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -daysAgo, to: start)!.addingTimeInterval(12 * 3600)
    }

    private func insertUsage(_ q: DatabaseQueue, pid: UUID, up: Int64, dn: Int64, at: Date) throws {
        try q.write { db in
            try UsageLog(id: UUID(), profileId: pid, uploadDelta: up, downloadDelta: dn,
                         recordedAt: at, sessionId: nil).insert(db)
        }
    }

    private func insertProfile(_ q: DatabaseQueue, ssid: String, quota: Double? = nil) throws -> UUID {
        let pid = UUID()
        let now = Date()
        try q.write { db in
            try Profile(id: pid, ssid: ssid, name: ssid, quotaGB: quota,
                        connectionType: "wifi", createdAt: now, lastConnected: now).insert(db)
        }
        return pid
    }

    @Test func refreshRollups_원천과일치() throws {
        let (q, _, engine) = try makeEngine()
        let pid = try insertProfile(q, ssid: "R1")
        try insertUsage(q, pid: pid, up: 100, dn: 200, at: noon(daysAgo: 0))
        try insertUsage(q, pid: pid, up: 300, dn: 400, at: noon(daysAgo: 3))
        engine.refreshRollups()
        let buckets = engine.dayBuckets(profileIds: [pid], days: 7)
        #expect(buckets.count == 2, "이틀치 버킷")
        #expect(buckets.reduce(0) { $0 + $1.total } == 1000, "합계 일치")
    }

    @Test func projectedExhaustion_자정전소진() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        // 하루 절반 경과 시점에 80% 사용 → 자정 전 소진 예상
        let now = start.addingTimeInterval(12 * 3600)
        let r = StatsEngine.projectedExhaustion(usedToday: 800_000_000, quotaBytes: 1_000_000_000, now: now)
        #expect(r != nil, "소진 예상 시각 반환")
        // 10% 사용이면 여유 → nil
        #expect(StatsEngine.projectedExhaustion(usedToday: 100_000_000, quotaBytes: 1_000_000_000, now: now) == nil)
        // 이미 초과 → now 반환
        #expect(StatsEngine.projectedExhaustion(usedToday: 1_500_000_000, quotaBytes: 1_000_000_000, now: now) == now)
    }

    @Test func paceInsights_한도초과_검출() throws {
        let (q, _, engine) = try makeEngine()
        let pid = try insertProfile(q, ssid: "P1", quota: 0.001)  // 1MB 한도
        try insertUsage(q, pid: pid, up: 2_000_000, dn: 0, at: Date())
        let insights = engine.paceInsights(profileIds: [pid])
        #expect(insights.count == 1 && insights[0].kind == .pace, "한도 초과 인사이트")
    }

    @Test func paceInsights_여유시_조용함() throws {
        let (q, _, engine) = try makeEngine()
        let pid = try insertProfile(q, ssid: "P2", quota: 10.0)  // 10GB 한도
        try insertUsage(q, pid: pid, up: 1_000_000, dn: 0, at: Date())
        #expect(engine.paceInsights(profileIds: [pid]).isEmpty, "여유분은 인사이트 없음")
    }

    @Test func topOffender_점유율40이상() throws {
        let (q, _, engine) = try makeEngine()
        let now = Date()
        try q.write { db in
            try AppTrafficLog(id: UUID(), processName: "TestApp358", uploadBytes: 80_000_000,
                              downloadBytes: 0, recordedAt: now).insert(db)
            try AppTrafficLog(id: UUID(), processName: "TestApp359", uploadBytes: 10_000_000,
                              downloadBytes: 0, recordedAt: now).insert(db)
        }
        engine.refreshRollups()
        let ins = engine.topOffenderInsight(days: 1)
        #expect(ins?.kind == .topOffender && ins?.appName == "TestApp358", "주범 지목")
    }

    @Test func anomaly_2배이상_검출() throws {
        let (q, _, engine) = try makeEngine()
        let pid = try insertProfile(q, ssid: "A1")
        for d in 1...7 {
            try insertUsage(q, pid: pid, up: 5_000_000, dn: 5_000_000, at: noon(daysAgo: d))
        }
        try insertUsage(q, pid: pid, up: 50_000_000, dn: 50_000_000, at: Date())
        engine.refreshRollups()
        let ins = engine.anomalyInsight(profileIds: [pid])
        #expect(ins?.kind == .anomaly, "급증 검출")
        #expect((ins?.ratio ?? 0) >= 2.0, "배율 2 이상")
    }

    @Test func anomaly_평소수준_조용함() throws {
        let (q, _, engine) = try makeEngine()
        let pid = try insertProfile(q, ssid: "A2")
        for d in 0...7 {
            try insertUsage(q, pid: pid, up: 5_000_000, dn: 5_000_000, at: noon(daysAgo: d))
        }
        engine.refreshRollups()
        #expect(engine.anomalyInsight(profileIds: [pid]) == nil, "평소 수준은 조용")
    }

    @Test func sessionEff_시간당1위() throws {
        let (q, _, engine) = try makeEngine()
        let pid = try insertProfile(q, ssid: "S1")
        let start = noon(daysAgo: 0).addingTimeInterval(-3600)
        let sid = UUID()
        try q.write { db in
            try Session(id: sid, profileId: pid, startTime: start,
                        endTime: start.addingTimeInterval(3600),
                        latitude: nil, longitude: nil, locationSource: nil).insert(db)
            try UsageLog(id: UUID(), profileId: pid, uploadDelta: 100_000_000,
                         downloadDelta: 0, recordedAt: Date(), sessionId: sid).insert(db)
        }
        _ = q
        let ins = engine.sessionEffInsight(profileIds: [pid], days: 1)
        #expect(ins?.kind == .sessionEff, "세션 효율 1위")
    }

    @Test func snapshot_통합() throws {
        let (q, _, engine) = try makeEngine()
        let pid = try insertProfile(q, ssid: "N1", quota: 10.0)
        try insertUsage(q, pid: pid, up: 100, dn: 200, at: noon(daysAgo: 0))
        try insertUsage(q, pid: pid, up: 300, dn: 400, at: noon(daysAgo: 1))
        engine.refreshRollups()
        let snap = engine.snapshot(profileIds: [pid], days: 7)
        #expect(snap.buckets.count == 2, "버킷 2일")
        #expect(snap.totalUpload == 400 && snap.totalDownload == 600, "합계 일치")
        #expect(snap.insights.allSatisfy { [.pace, .topOffender, .anomaly, .sessionEff].contains($0.kind) })
    }
}
