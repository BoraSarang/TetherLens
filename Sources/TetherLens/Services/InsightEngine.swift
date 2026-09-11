import Foundation

/// 인사이트 종류 (v0.36). UI는 kind별 문구를 조합한다 — 엔진은 수치만 반환.
enum InsightKind: String {
    case pace          // 한도 소진 예측 (오늘 페이스)
    case topOffender   // 오늘 소모 주범 앱
    case surge         // 평소 대비 급증
    case nightDrain    // 심야 시간대 소모 집중
    case uploadHeavy   // 업로드 비중 비정상
    case ipChurn       // 최근 IP 변경 잦음
}

/// UI에 구애받지 않는 인사이트 데이터. 발동 조건을 만족할 때만 생성된다.
struct InsightItem: Identifiable, Equatable {
    let id = UUID()
    let kind: InsightKind
    var profileName: String?
    var appName: String?
    var ratio: Double?
    var bytes: Int64?
    var date: Date?
    var count: Int?

    static func == (lhs: InsightItem, rhs: InsightItem) -> Bool {
        lhs.kind == rhs.kind && lhs.profileName == rhs.profileName
            && lhs.appName == rhs.appName && lhs.ratio == rhs.ratio
            && lhs.bytes == rhs.bytes && lhs.count == rhs.count
    }
}

/// 엔진 입력 — 호출자가 ProfileManager 기존 조회로 채운다 (DB 접근 없음).
struct InsightInput {
    struct ProfileData {
        let id: UUID
        let name: String
        let quotaBytes: Int64?
        let todayUpload: Int64
        let todayDownload: Int64
        /// 최근 8일 일별 합계 (day: "yyyy-MM-dd", 오늘 포함, 순서 무관)
        let dailyTotals: [(day: String, total: Int64)]
        /// 오늘 시간대별 합계 (hour: 0~23)
        let hourlyTotals: [(hour: Int, total: Int64)]
        /// 최근 7일 distinct IP 수
        let recentDistinctIPs: Int
    }
    /// 오늘 앱별 합계 (시스템 프로세스 포함 가능 — 엔진이 제외)
    let topApps: [(name: String, total: Int64)]
    let profiles: [ProfileData]
    let todayKey: String
    let now: Date
}

/// 인사이트 규칙 단일 진입점 (v0.36). DB 마이그레이션 없이 기존 집계 재사용.
enum InsightEngine {
    static let surgeRatio = 2.0
    static let surgeBaseline: Int64 = 10_000_000
    static let offenderShare = 0.4
    static let offenderMinimum: Int64 = 50_000_000
    static let nightShare = 0.3
    static let nightMinimum: Int64 = 50_000_000
    static let uploadShare = 0.4
    static let uploadMinimum: Int64 = 50_000_000
    static let ipChurnCount = 5

    static func build(_ input: InsightInput) -> [InsightItem] {
        var items: [InsightItem] = []
        for p in input.profiles {
            let today = p.todayUpload + p.todayDownload
            if let quota = p.quotaBytes,
               let exhaustion = projectedExhaustion(usedToday: today, quotaBytes: quota, now: input.now) {
                items.append(InsightItem(kind: .pace, profileName: p.name,
                                         ratio: min(Double(today) / Double(quota), 9.99),
                                         bytes: today, date: exhaustion))
            }
            if let ratio = surgeTriggered(dailyTotals: p.dailyTotals, todayKey: input.todayKey) {
                items.append(InsightItem(kind: .surge, profileName: p.name, ratio: ratio, bytes: today))
            }
            if let share = nightDrainShare(hourlyTotals: p.hourlyTotals, todayTotal: today) {
                items.append(InsightItem(kind: .nightDrain, profileName: p.name, ratio: share, bytes: today))
            }
            if let share = uploadHeavyShare(upload: p.todayUpload, total: today) {
                items.append(InsightItem(kind: .uploadHeavy, profileName: p.name, ratio: share, bytes: today))
            }
            if p.recentDistinctIPs >= ipChurnCount {
                items.append(InsightItem(kind: .ipChurn, profileName: p.name, count: p.recentDistinctIPs))
            }
        }
        if let offender = topOffender(apps: input.topApps) {
            // 주범 앱은 프로필 단위가 아닌 전역 집계라 맨 앞에 둔다
            items.insert(offender, at: 0)
        }
        return items
    }

    /// 오늘 페이스로 자정 전 한도 소진 예상 시각. 자정 이후 소진이면 nil.
    static func projectedExhaustion(usedToday: Int64, quotaBytes: Int64, now: Date = Date()) -> Date? {
        guard quotaBytes > 0, usedToday >= 0 else { return nil }
        if usedToday >= quotaBytes { return now }
        let startOfDay = Calendar.current.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(startOfDay)
        guard elapsed > 900, usedToday > 0 else { return nil }
        let rate = Double(usedToday) / elapsed
        let exhaustion = now.addingTimeInterval(Double(quotaBytes - usedToday) / rate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return exhaustion < endOfDay ? exhaustion : nil
    }

    /// 오늘 사용량이 최근 7일 평균의 surgeRatio 배 이상이면 배율 반환.
    static func surgeTriggered(dailyTotals: [(day: String, total: Int64)], todayKey: String) -> Double? {
        guard let today = dailyTotals.first(where: { $0.day == todayKey })?.total, today > 0 else { return nil }
        let prior = dailyTotals.filter { $0.day != todayKey }.map(\.total)
        guard !prior.isEmpty else { return nil }
        let avg = Double(prior.reduce(0, +)) / Double(prior.count)
        guard avg >= Double(surgeBaseline) else { return nil }
        let ratio = Double(today) / avg
        return ratio >= surgeRatio ? ratio : nil
    }

    /// 1위 앱이 전체의 offenderShare 이상이면 인사이트 반환 (시스템 프로세스 제외).
    static func topOffender(apps: [(name: String, total: Int64)]) -> InsightItem? {
        let user = apps.filter { !SystemProcesses.set.contains($0.name) && $0.total > 0 }
        guard let top = user.max(by: { $0.total < $1.total }) else { return nil }
        let total = user.reduce(0) { $0 + $1.total }
        guard total >= offenderMinimum else { return nil }
        let share = Double(top.total) / Double(total)
        guard share >= offenderShare else { return nil }
        return InsightItem(kind: .topOffender, appName: top.name, ratio: share, bytes: top.total)
    }

    /// 00–06시 합계가 오늘의 nightShare 이상이면 비중 반환.
    static func nightDrainShare(hourlyTotals: [(hour: Int, total: Int64)], todayTotal: Int64) -> Double? {
        guard todayTotal >= nightMinimum else { return nil }
        let night = hourlyTotals.filter { $0.hour >= 0 && $0.hour < 6 }.reduce(0) { $0 + $1.total }
        let share = Double(night) / Double(todayTotal)
        return share >= nightShare ? share : nil
    }

    /// 오늘 업로드 비중이 uploadShare 이상이면 비중 반환.
    static func uploadHeavyShare(upload: Int64, total: Int64) -> Double? {
        guard total >= uploadMinimum, total > 0 else { return nil }
        let share = Double(upload) / Double(total)
        return share >= uploadShare ? share : nil
    }
}
