import Testing
import Foundation
import GRDB
@testable import TetherLens

@Suite struct ProfileManagerTests {

    private func makeManager() throws -> (DatabaseQueue, ProfileManager) {
        let q = try DatabaseQueue()
        try DataStore.makeMigrator().migrate(q)
        return (q, ProfileManager(db: q))
    }

    private func makeProfile(ssid: String = "iPhone-123", name: String = "내 핫스팟") -> Profile {
        Profile(
            id: UUID(), ssid: ssid, name: name,
            quotaGB: 10, connectionType: "ios_hotspot",
            createdAt: Date(), lastConnected: Date()
        )
    }

    // MARK: - 프로필 CRUD

    @Test func 프로필_저장_조회_삭제() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let found = pm.getProfile(ssid: "iPhone-123")
        #expect(found != nil)
        #expect(found?.id == p.id)
        #expect(found?.ssid == p.ssid)
        #expect(found?.name == p.name)
        #expect(found?.quotaGB == p.quotaGB)
        #expect(found?.connectionType == p.connectionType)
        #expect(found.map { abs($0.createdAt.timeIntervalSince(p.createdAt)) < 1 } ?? false, "Date 근사 비교")
        #expect(pm.getProfile(id: p.id)?.id == p.id)
        #expect(pm.getAllProfiles().count == 1)

        pm.deleteProfile(id: p.id)
        #expect(pm.getProfile(ssid: "iPhone-123") == nil)
        #expect(pm.getAllProfiles().isEmpty)
        _ = q
    }

    @Test func autoRegister_기존_갱신과_신규_생성() throws {
        let (_, pm) = try makeManager()
        let first = pm.autoRegisterIfNeeded(ssid: "WiFi-5G", connectionType: "wifi")
        #expect(first.name == "WiFi-5G")
        #expect(first.connectionType == "wifi")

        let second = pm.autoRegisterIfNeeded(ssid: "WiFi-5G", connectionType: "ethernet")
        #expect(second.id == first.id, "같은 SSID는 같은 프로필 재사용")
        #expect(second.connectionType == "ethernet", "연결 타입 갱신")
        #expect(pm.getAllProfiles().count == 1)
    }

    @Test func autoRegister_핫스팟_연결타입_어휘() throws {
        let (_, pm) = try makeManager()
        // MenuBarManager.connectionTypeString은 스네이크케이스("ios_hotspot"/"android_hotspot")로 전달
        let ios = pm.autoRegisterIfNeeded(ssid: "iPhone 15", connectionType: "ios_hotspot")
        #expect(ios.isHotspot, "스네이크케이스 저장 시 isHotspot 인식")
        #expect(ios.typeLabel != nil)

        let android = pm.autoRegisterIfNeeded(ssid: "GALAXY S24", connectionType: "android_hotspot")
        #expect(android.isHotspot, "android_hotspot 저장 시 isHotspot 인식")

        // 과거 버그에서 저장된 카멜케이스는 v9 마이그레이션에서 정규화되며,
        // 정규화 이전에도 isHotspot이 false로 남는 것을 방지한다.
        let legacy = pm.autoRegisterIfNeeded(ssid: "OLD_HOTSPOT", connectionType: "iOSHotspot")
        #expect(!legacy.isHotspot, "카멜케이스는 isHotspot 인식 안 됨(정규화 대상)")
    }

    @Test func SSID_연결타입_분류() {
        #expect(Profile.classifiedConnectionType(ssid: "iPhone 15") == "ios_hotspot")
        #expect(Profile.classifiedConnectionType(ssid: "내 iPAD") == "ios_hotspot")
        #expect(Profile.classifiedConnectionType(ssid: "GALAXY S24") == "android_hotspot")
        #expect(Profile.classifiedConnectionType(ssid: "SM-A536") == "android_hotspot")
        #expect(Profile.classifiedConnectionType(ssid: "HOME_WIFI") == "wifi")
        #expect(Profile.classifiedConnectionType(ssid: "iPhone") != "wifi")
    }

    // MARK: - 사용량 누적 델타

    @Test func recordUsage_누적_델타_계산() throws {
        let (_, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)

        // 첫 호출: 시드만 저장 (델타 0)
        pm.recordUsage(totalUpload: 1000, totalDownload: 2000, profileId: p.id)
        #expect(pm.getTotalUsage(profileId: p.id).upload == 0)

        pm.recordUsage(totalUpload: 3000, totalDownload: 2500, profileId: p.id)
        let total = pm.getTotalUsage(profileId: p.id)
        #expect(total.upload == 2000)
        #expect(total.download == 500)

        // 업로드가 음수로 감소 → 업로드 축만 리셋, 다운로드 양수 델타는 정상 기록
        pm.recordUsage(totalUpload: 2500, totalDownload: 2600, profileId: p.id)
        let afterReset = pm.getTotalUsage(profileId: p.id)
        #expect(afterReset.upload == 2000)
        #expect(afterReset.download == 600)

        // 리셋된 카운터 기준 새 델타가 정상 반영
        pm.recordUsage(totalUpload: 3500, totalDownload: 3000, profileId: p.id)
        let afterNext = pm.getTotalUsage(profileId: p.id)
        #expect(afterNext.upload == 3000)
        #expect(afterNext.download == 1000)
    }

    @Test func 프로필_전환_시_타프로필_이중계상_방지() throws {
        let (_, pm) = try makeManager()
        let a = makeProfile(ssid: "WiFi-A")
        let b = makeProfile(ssid: "WiFi-B")
        pm.saveProfile(a)
        pm.saveProfile(b)

        // A 접속: 시드 → 델타 (A: 200/200)
        pm.recordUsage(totalUpload: 100, totalDownload: 200, profileId: a.id)
        pm.recordUsage(totalUpload: 300, totalDownload: 400, profileId: a.id)

        // B로 전환: B 카운터 재시드 후 기록 (B: 200/200)
        pm.resetCounter(profileId: b.id, totalUpload: 300, totalDownload: 400)
        pm.recordUsage(totalUpload: 500, totalDownload: 600, profileId: b.id)

        // 다시 A로 전환: A 카운터 재시드 → B 기간 트래픽(200/200)이 A에 이중 계상되지 않음
        pm.resetCounter(profileId: a.id, totalUpload: 500, totalDownload: 600)
        pm.recordUsage(totalUpload: 700, totalDownload: 800, profileId: a.id)

        // A: 첫 기록(200/200) + 전환 후 새 델타(200/200) = 400/400
        // (재시드 없이 B 기간 트래픽까지 합산되면 600/600이 됨)
        #expect(pm.getTotalUsage(profileId: a.id).upload == 400)
        #expect(pm.getTotalUsage(profileId: a.id).download == 400)
        #expect(pm.getTotalUsage(profileId: b.id).upload == 200)
        #expect(pm.getTotalUsage(profileId: b.id).download == 200)
    }

    @Test func getTodayUsage_합계() throws {
        let (_, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        pm.recordUsage(totalUpload: 0, totalDownload: 0, profileId: p.id)
        pm.recordUsage(totalUpload: 500_000_000, totalDownload: 1_000_000_000, profileId: p.id)
        let today = pm.getTodayUsage(profileId: p.id)
        #expect(today.upload == 500_000_000)
        #expect(today.download == 1_000_000_000)
    }

    @Test func daily_monthly_요약() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let now = Date()
        try q.write { db in
            try UsageLog(id: UUID(), profileId: p.id, uploadDelta: 100, downloadDelta: 200, recordedAt: now, sessionId: nil).insert(db)
            try UsageLog(id: UUID(), profileId: p.id, uploadDelta: 300, downloadDelta: 400, recordedAt: now, sessionId: nil).insert(db)
        }
        let daily = pm.getDailyUsage(profileId: p.id, days: 7)
        #expect(daily.count == 1)
        #expect(daily[0].upload == 400)
        #expect(daily[0].download == 600)

        let monthly = pm.getMonthlyUsage(profileId: p.id, months: 1)
        #expect(monthly.count == 1)
        #expect(monthly[0].total == 1000)
    }

    // MARK: - 세션

    @Test func 세션_시작_종료_활성() throws {
        let (_, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let s = pm.startSession(profileId: p.id)
        #expect(pm.getActiveSession(profileId: p.id)?.id == s.id)
        pm.endSession(s)
        #expect(pm.getActiveSession(profileId: p.id) == nil)
        #expect(pm.getSessions(profileId: p.id, days: 7).count == 1)
    }

    @Test func 세션_사용량_연결() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let s = pm.startSession(profileId: p.id)
        pm.recordUsage(totalUpload: 0, totalDownload: 0, profileId: p.id, sessionId: s.id)
        pm.recordUsage(totalUpload: 1000, totalDownload: 2000, profileId: p.id, sessionId: s.id)
        let usage = pm.getSessionUsage(sessionId: s.id)
        #expect(usage.upload == 1000)
        #expect(usage.download == 2000)
        _ = q
    }

    // MARK: - IP 로그

    @Test func IP_로그_1800초_dedup() throws {
        let (_, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        pm.addIPLog(profileId: p.id, ipAddress: "1.2.3.4", country: "KR", latitude: 1, longitude: 2)
        pm.addIPLog(profileId: p.id, ipAddress: "1.2.3.4", country: "KR", latitude: 1, longitude: 2)
        #expect(pm.getIPLogs(profileId: p.id).count == 1)
        pm.addIPLog(profileId: p.id, ipAddress: "5.6.7.8", country: "US", latitude: 3, longitude: 4)
        #expect(pm.getIPLogs(profileId: p.id).count == 2)
    }

    @Test func mergeStaleIPLogs_병합() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let now = Date()
        let old = IPLog(id: UUID(), profileId: p.id, ipAddress: "9.9.9.9", country: nil, latitude: nil, longitude: nil,
                        firstSeenAt: now.addingTimeInterval(-7200), lastSeenAt: now.addingTimeInterval(-3600))
        let newer = IPLog(id: UUID(), profileId: p.id, ipAddress: "9.9.9.9", country: "US", latitude: 3, longitude: 4,
                          firstSeenAt: now.addingTimeInterval(-3000), lastSeenAt: now.addingTimeInterval(-1000))
        try q.write { db in
            try old.insert(db)
            try newer.insert(db)
        }
        pm.mergeStaleIPLogs()
        let logs = pm.getIPLogs(profileId: p.id)
        #expect(logs.count == 1)
        #expect(logs[0].firstSeenAt.timeIntervalSince(old.firstSeenAt) < 1, "병합 후 min(first_seen_at)")
        #expect(logs[0].lastSeenAt.timeIntervalSince(newer.lastSeenAt) < 1, "병합 후 max(last_seen_at)")
        #expect(logs[0].country == "US")
    }

    @Test func getIPForSession_시간_범위_매칭() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let start = Date().addingTimeInterval(-600)
        let s = Session(id: UUID(), profileId: p.id, startTime: start, endTime: nil, latitude: nil, longitude: nil)
        try q.write { db in
            try s.insert(db)
            try IPLog(id: UUID(), profileId: p.id, ipAddress: "8.8.8.8", country: "US", latitude: 1, longitude: 1,
                      firstSeenAt: start.addingTimeInterval(60), lastSeenAt: start.addingTimeInterval(120)).insert(db)
        }
        let match = pm.getIPForSession(s)
        #expect(match?.ipAddress == "8.8.8.8")
    }

    // MARK: - 정리/내보내기

    @Test func cleanupOldLogs_오래된_로그_삭제() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let oldDate = Date().addingTimeInterval(-366 * 86_400)
        let newDate = Date()
        try q.write { db in
            try UsageLog(id: UUID(), profileId: p.id, uploadDelta: 100, downloadDelta: 100, recordedAt: oldDate, sessionId: nil).insert(db)
            try UsageLog(id: UUID(), profileId: p.id, uploadDelta: 200, downloadDelta: 200, recordedAt: newDate, sessionId: nil).insert(db)
        }
        pm.cleanupOldLogs()
        let logs = pm.getUsageLogs(profileId: p.id, days: 3650)
        #expect(logs.count == 1)
        #expect(logs[0].uploadDelta == 200)
    }

    @Test func cleanupOldLogs_세션_연쇄_삭제() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let oldSession = Session(id: UUID(), profileId: p.id,
                                 startTime: Date().addingTimeInterval(-367 * 86_400),
                                 endTime: Date().addingTimeInterval(-366 * 86_400),
                                 latitude: nil, longitude: nil)
        let oldUsage = UsageLog(id: UUID(), profileId: p.id, uploadDelta: 100, downloadDelta: 100,
                                recordedAt: oldSession.startTime, sessionId: oldSession.id)
        try q.write { db in
            try oldSession.insert(db)
            try oldUsage.insert(db)
        }
        pm.cleanupOldLogs()
        #expect(pm.getSessions(profileId: p.id, days: 3650).isEmpty)
        #expect(pm.getUsageLogs(profileId: p.id, days: 3650).isEmpty)
    }

    @Test func exportData_CSV_이스케이프() throws {
        let (_, pm) = try makeManager()
        let p = makeProfile(name: "핫,스팟 \"A\"")
        pm.saveProfile(p)
        let s = pm.startSession(profileId: p.id)
        pm.endSession(s)
        let data = pm.exportData(profileId: p.id)
        #expect(data.csv.contains("\"핫,스팟 \"\"A\"\"\""))
        #expect(data.csv.hasPrefix("Profile,Type,Start,End,Value\n"))
    }

    @Test func exportData_CSV_따옴표_쿼팅() throws {
        let (_, pm) = try makeManager()
        let p = makeProfile(name: "따옴표\"만")
        pm.saveProfile(p)
        let s = pm.startSession(profileId: p.id)
        pm.endSession(s)
        let data = pm.exportData(profileId: p.id)
        #expect(data.csv.contains("\"따옴표\"\"만\""), "따옴표만 있는 값도 전체 쿼팅되어야 함")
    }

    @Test func cleanupOldLogs_활성세션_정리() throws {
        let (q, pm) = try makeManager()
        let p = makeProfile()
        pm.saveProfile(p)
        let stale = Session(id: UUID(), profileId: p.id,
                            startTime: Date().addingTimeInterval(-367 * 86_400),
                            endTime: nil, latitude: nil, longitude: nil)
        try q.write { db in
            try stale.insert(db)
        }
        pm.cleanupOldLogs()
        #expect(pm.getSessions(profileId: p.id, days: 3650).isEmpty, "1년 넘게 end_time이 없는 활성 세션도 정리")
    }

    @Test func getTodayUsage_프로필별_캐시_격리() throws {
        let (_, pm) = try makeManager()
        let a = makeProfile(ssid: "Cache-A")
        let b = makeProfile(ssid: "Cache-B")
        pm.saveProfile(a)
        pm.saveProfile(b)

        pm.recordUsage(totalUpload: 0, totalDownload: 0, profileId: a.id)
        pm.recordUsage(totalUpload: 1000, totalDownload: 2000, profileId: a.id)
        pm.recordUsage(totalUpload: 0, totalDownload: 0, profileId: b.id)
        pm.recordUsage(totalUpload: 500, totalDownload: 700, profileId: b.id)

        let aToday = pm.getTodayUsage(profileId: a.id)
        let bToday = pm.getTodayUsage(profileId: b.id)
        #expect(aToday.upload == 1000)
        #expect(aToday.download == 2000)
        #expect(bToday.upload == 500)
        #expect(bToday.download == 700)

        // 프로필 전환 후 재조회 시 다른 프로필 값이 섞이지 않음
        let aAgain = pm.getTodayUsage(profileId: a.id)
        #expect(aAgain.upload == 1000)
    }

    @Test func getAppTrafficLogs_집계() throws {
        let (q, pm) = try makeManager()
        let now = Date()
        try q.write { db in
            try AppTrafficLog(id: UUID(), processName: "Safari", uploadBytes: 100, downloadBytes: 200, recordedAt: now).insert(db)
            try AppTrafficLog(id: UUID(), processName: "Safari", uploadBytes: 50, downloadBytes: 100, recordedAt: now).insert(db)
            try AppTrafficLog(id: UUID(), processName: "Chrome", uploadBytes: 1000, downloadBytes: 500, recordedAt: now).insert(db)
        }
        let logs = pm.getAppTrafficLogs(days: 1)
        let safari = logs.first { $0.processName == "Safari" }
        let chrome = logs.first { $0.processName == "Chrome" }
        #expect(safari?.uploadBytes == 150)
        #expect(safari?.downloadBytes == 300)
        #expect(chrome?.uploadBytes == 1000)
        #expect(logs.first?.processName == "Chrome", "합계순 정렬")
    }
}
