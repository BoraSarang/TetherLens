import Foundation
import Combine

/// 대시보드 DB 집계 스냅샷 (60초 주기)
///
/// **설계 원칙 (RelayConsole 이식)**
/// - 대시보드의 실시간 카드(속도·시스템)는 각자가 `@Published` 를 직접 관찰한다.
///   본 스토어는 **DB 조회가 필요한 값만** 60초 주기로 1회 집계해 스냅샷 1회로 발행한다.
/// - `@Published` 는 대입마다 `objectWillChange` 를 발화하므로 **불변 복사 후 1회만 대입**한다.
@MainActor
final class DashboardStore: ObservableObject {
    static let shared = DashboardStore()

    /// 대시보드가 읽는 모든 DB 파생 값의 단일 스냅샷
    struct Snapshot: Equatable {
        /// 마지막 집계 시각 — 헤더 "갱신 N초 전" 표기용
        var lastUpdated: Date = .distantPast
        /// 현재 SSID에 대응하는 프로필 이름. `hasProfile == false` 면 미등록 상태
        var profileName: String?
        var hasProfile: Bool = false
        /// 오늘 업/다운로드 합계 (바이트)
        var todayUpload: Int64 = 0
        var todayDownload: Int64 = 0
        /// 일일 할당량 (GB). nil = 미설정
        var quotaGB: Double?
        /// 오늘 세션 건수 / 총 지속 시간
        var sessionCount: Int = 0
        var sessionDuration: TimeInterval = 0
        /// 오늘 0~23시 총량 (0시..23시). 데이터 없는 구간은 0 (차트 축 고정용)
        var hourlyTotals: [Int64] = Array(repeating: 0, count: 24)
        /// 최근 8일 일별 총량 (오래된 → 오늘)
        var dailyTotals: [Int64] = []
        /// `hourlyTotals` 의 총합 (비율 계산 분모)
        var hourlySum: Int64 { hourlyTotals.reduce(0, +) }
        /// 인사이트 6종 — 60초 주기로 상시 계산 (v0.39. 이전엔 차트 탭 진입 시에만)
        var insights: [InsightItem] = []
        /// `dailyTotals` 의 최댓값 (스파크라인 정규화)
        var dailyPeak: Int64 { dailyTotals.max() ?? 0 }
        /// 현재 활성 세션 시작 시각 (없으면 nil)
        var sessionStart: Date?

        var todayTotal: Int64 { todayUpload + todayDownload }
        var todayUsedGB: Double { Double(todayTotal) / 1_000_000_000 }
        /// 오늘 데이터가 하나도 없는 상태 (0을 "0으로 표시"가 아니라 "미측정/없음"으로 다루기 위한 구분)
        var hasTodayUsage: Bool { todayTotal > 0 }
    }

    @Published private(set) var snapshot = Snapshot()

    private var timer: Timer?
    private var refCount = 0

    private init() {}

    // MARK: - 수명 (창이 열려 있을 때만 폴링)

    /// 창이 열릴 때 1회 호출 (`.onAppear`). 중복 호출은 첫 회차만 실제 시작.
    func acquire() {
        refCount += 1
        guard refCount == 1 else { return }
        refresh()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 창이 닫힐 때 호출 (`.onDisappear`). 마지막 참조가 사라지면 타이머 해제.
    func release() {
        refCount = max(refCount - 1, 0)
        guard refCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    /// 프로필 편집·할당량 변경 직후 즉시 재집계 (창이 열려 있을 때만)
    func refreshNow() {
        guard refCount > 0 else { return }
        refresh()
    }

    // MARK: - 집계

    private func refresh() {
        let pm = ProfileManager.shared
        let connection = AppServices.shared.hotspotDetector?.currentConnection

        var next = Snapshot()
        next.lastUpdated = Date()

        if let ssid = Self.ssid(of: connection) {
            if let profile = pm.getProfile(ssid: ssid) {
                next.hasProfile = true
                next.profileName = profile.name
                next.quotaGB = profile.quotaGB
                let (up, down) = pm.getTodayUsage(profileId: profile.id)
                next.todayUpload = up
                next.todayDownload = down
                next.sessionStart = Self.activeSessionStart(profileId: profile.id, now: next.lastUpdated)
                if let today = pm.getDailySessionSummary(profileId: profile.id, days: 1).first {
                    next.sessionCount = today.sessionCount
                    next.sessionDuration = today.totalDuration
                }
                next.hourlyTotals = Self.hourBuckets(pm.getHourlyUsageToday(profileId: profile.id))
                next.dailyTotals = pm.getDailyUsage(profileId: profile.id, days: 8).map(\.total)
                next.insights = InsightProvider.build(profiles: [profile], now: next.lastUpdated)
            }
        }

        // 불변 복사 후 1회만 대입 — 두 번 대입하면 중간 상태가 관측되어 전체 재렌더가 붙는다
        snapshot = next
    }

    // MARK: - 헬퍼 (순수 함수 — 테스트 가능)

    /// 시간대 집계(데이터 없는 구간 0 채움) → 0~23시 배열 (24칸 고정)
    nonisolated static func hourBuckets(_ usage: [ProfileManager.HourlyUsage]) -> [Int64] {
        var buckets = Array(repeating: Int64(0), count: 24)
        for u in usage where u.hour >= 0 && u.hour < 24 {
            buckets[u.hour] = u.total
        }
        return buckets
    }

    /// 연결 정보에서 프로필 조회 키(SSID) 추출. 알 수 없는 연결이면 nil.
    nonisolated static func ssid(of connection: ConnectionInfo?) -> String? {
        guard let connection else { return nil }
        switch connection.type {
        case .normalWiFi(let ssid, _):
            return ssid ?? connection.interfaceName
        case .iOSPersonalHotspot(let ssid):
            return ssid ?? connection.interfaceName
        case .androidHotspot(let ssid):
            return ssid ?? connection.interfaceName
        case .ethernet:
            return connection.interfaceName
        case .unknown:
            return nil
        }
    }

    /// 프로필의 활성(종료 안 됨) 세션 시작 시각
    nonisolated static func activeSessionStart(profileId: UUID, now: Date = Date()) -> Date? {
        ProfileManager.shared.getSessions(profileId: profileId, days: 1)
            .first { $0.endTime == nil }?
            .startTime
    }
}
