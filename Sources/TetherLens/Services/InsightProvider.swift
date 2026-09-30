import Foundation

/// 인사이트 입력 조립 — `ProfileManager` 기존 조회로 `InsightInput` 을 만든다.
///
/// v0.39 이전에는 `UsageReportView.refreshInsights()` 안에 인라인돼 있었고
/// **차트 탭 진입 시에만** 계산됐다. 대시보드에서 상시 표시하려면
/// 탭 조건과 무관하게 호출할 수 있어야 하므로 전용 프로바이더로 분리했다.
/// (DB 마이그레이션 없음 — 기존 조회 5종 조합)
enum InsightProvider {

    /// 인사이트에 사용하는 일별 집계 일수 (7일 평균 + 오늘)
    static let dailyDays = 8
    /// IP 변경 집계 기준 (일)
    static let ipWindowDays = 7

    /// 프로필 목록으로 인사이트 계산
    /// - Parameters:
    ///   - profiles: 대상 프로필. 빈 배열이면 프로필 미등록 상태로 빈 결과
    ///   - topAppsDays: 앱 트래픽 집계 기간 (일). 오늘 인사이트는 1
    static func build(profiles: [Profile], topAppsDays: Int = 1, now: Date = Date()) -> [InsightItem] {
        let pm = ProfileManager.shared
        let todayKey = Self.dayKey(now)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -ipWindowDays, to: now) ?? .distantPast

        let pdata: [InsightInput.ProfileData] = profiles.map { p in
            let today = pm.getTodayUsage(profileId: p.id)
            let daily = pm.getDailyUsage(profileId: p.id, days: dailyDays)
            // 오늘 자정 이후 한정 — getHourlyUsage(days:1) 는 어제 데이터가 섞여
            // nightDrain 비율이 100%를 넘게 만든다 (v0.39 수정)
            let hourly = pm.getHourlyUsageToday(profileId: p.id)
            let ipCount = Set(
                pm.getIPLogs(profileId: p.id)
                    .filter { $0.firstSeenAt >= weekAgo }
                    .map(\.ipAddress)
            ).count
            return InsightInput.ProfileData(
                id: p.id,
                name: p.name,
                quotaBytes: p.quotaGB.map { Int64($0 * 1_000_000_000) },
                todayUpload: today.upload,
                todayDownload: today.download,
                dailyTotals: daily.map { (day: $0.id, total: $0.total) },
                hourlyTotals: hourly.map { (hour: $0.hour, total: $0.total) },
                recentDistinctIPs: ipCount
            )
        }

        let apps = pm.getAppTrafficLogs(days: topAppsDays)
            .map { (name: $0.processName, total: $0.uploadBytes + $0.downloadBytes) }

        let items = InsightEngine.build(
            InsightInput(topApps: apps, profiles: pdata, todayKey: todayKey, now: now)
        )
        let kinds = items.map(\.kind.rawValue).joined(separator: ",")
        Task { @MainActor in
            DebugLogger.shared.action("Stats", "[FEATURE] Insight \(items.count)개 (\(kinds))")
        }
        return items
    }

    /// "yyyy-MM-dd" — `InsightEngine.surgeTriggered` 의 `todayKey` 비교 규약
    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
