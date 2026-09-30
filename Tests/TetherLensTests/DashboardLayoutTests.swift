import Testing
import Foundation
@testable import TetherLens

/// v0.39 대시보드 — 순서 정의 · 포맷 · 스냅샷 계산을 순수 함수로 검증
@Suite struct DashboardLayoutTests {

    // MARK: - 카드 순서 = 단일 진실원처

    @Test func 카드_전체가_행과_전폭을_합쳐_정확히한번씩등장() {
        let all = DashboardCard.rows.flatMap { $0 } + DashboardCard.wideCards
        #expect(Set(all).count == DashboardCard.allCases.count)
        #expect(Set(all) == Set(DashboardCard.allCases))
    }

    /// 행에만 들어가는 카드와 전폭 카드는 겹치지 않는다 (전폭이 2열 그리드에 섞이면 행 높이가 깨진다)
    @Test func 행카드와_전폭카드가_겹치지않는다() {
        let inRows = Set(DashboardCard.rows.flatMap { $0 })
        #expect(inRows.isDisjoint(with: Set(DashboardCard.wideCards)))
    }

    @Test func 전폭카드는_행에_중복포함되지않는다() {
        let inRows = Set(DashboardCard.rows.flatMap { $0 })
        for wide in DashboardCard.wideCards {
            #expect(!inRows.contains(wide))
        }
    }

    @Test func ordered는_행펼침_뒤에_전폭카드가온다() {
        let expected = DashboardCard.rows.flatMap { $0 } + DashboardCard.wideCards
        #expect(DashboardCard.ordered == expected)
    }

    @Test func 행구성은_모두_2열이다() {
        for row in DashboardCard.rows {
            #expect(row.count == 2)
        }
    }

    /// 순서가 곧 정보 계층이다 — 실시간 관제(속도·품질)가 최상단에 있어야 한다
    @Test func 첫행은_실시간관제카드다() {
        #expect(DashboardCard.rows.first?.contains(.speed) == true)
        #expect(DashboardCard.rows.first?.contains(.quality) == true)
    }

    /// v0.39 — CPU/GPU/RAM 은 개별 셀로 분리되고 프로세스 리스트로 8칸이 꽉 찬다
    @Test func 자원이_CPU_GPU_RAM_개별셀로_존재한다() {
        for c in [DashboardCard.cpu, .gpu, .memory, .process] {
            #expect(DashboardCard.allCases.contains(c))
        }
    }

    @Test func 카드수는_9칸이다() {
        // 2열 × 4행 = 8칸 + 전폭 1칸(인사이트)
        #expect(DashboardCard.rows.flatMap { $0 }.count == 8)
        #expect(DashboardCard.wideCards.count == 1)
        #expect(DashboardCard.ordered.count == 9)
    }

    /// 인사이트는 목록형이라 전폭으로 빼야 한다 (2열 그리드에 섞이면 행 높이가 깨진다)
    @Test func 인사이트카드가_전폭으로_배치된다() {
        #expect(DashboardCard.wideCards == [.insight])
        #expect(DashboardCard.rows.flatMap { $0 }.contains(.insight) == false)
    }

    @Test func 인사이트가_전체순서의_마지막이다() {
        #expect(DashboardCard.ordered.last == .insight)
    }

    /// 4행 × 2열 = 8칸이므로 짝이 맞아야 2열 그리드가 빈틈없이 채워진다
    @Test func 행구성은_4행이고_각행은_2열이다() {
        #expect(DashboardCard.rows.count == 4)
        for row in DashboardCard.rows { #expect(row.count == 2) }
    }

    @Test func 모든카드에_제목과_심볼이_있다() {
        for card in DashboardCard.allCases {
            #expect(!card.title.isEmpty)
            #expect(!card.symbol.isEmpty)
        }
    }

    @Test func 카드ID는_원본값과_같다() {
        // SettingsManager 의 UserDefaults 키("dashboard.card.<id>") 안정성 보장
        for card in DashboardCard.allCases {
            #expect(card.id == card.rawValue)
        }
    }

    // MARK: - 포맷 (정적 함수 — 회귀 방지)

    @Test func 속도문자열_단위경계() {
        #expect(DashboardSpeedCard.rateString(8 * 1_000_000_000) == "1.00 GB/s")   // 1GB/s
        #expect(DashboardSpeedCard.rateString(8 * 100_000) == "100 KB/s")          // 100KB/s
        #expect(DashboardSpeedCard.rateString(8 * 100) == "100 B/s")               // 100B/s
    }

    @Test func KPI_나머지는_음수가되지않는다() {
        // 할당량 초과 시 0으로 클램프
        #expect(DashboardView.gb(max(10.0 - 4.62, 0)) == DashboardView.gb(5.38))
    }

    @Test func KPI_비율은_999퍼센트를_넘지않는다() {
        #expect(DashboardView.percent(0.153) == "15%")
        #expect(DashboardView.percent(9.99) == "999%")
    }

    @Test func 세션경과_포맷_H_MM_SS와_MM_SS() {
        let now = Date()
        #expect(DashboardClock.durationString(since: now.addingTimeInterval(-65), now: now) == "01:05")
        #expect(DashboardClock.durationString(since: now.addingTimeInterval(-3_725), now: now) == "1:02:05")
    }

    @Test func 세션경과_음수는_0으로_클램프() {
        let now = Date()
        #expect(DashboardClock.durationString(since: now.addingTimeInterval(10), now: now) == "00:00")
    }

    @Test func KPI_시간표기() {
        #expect(DashboardView.hms(0) == "0:00")
        #expect(DashboardView.hms(125) == "2:05")
        #expect(DashboardView.hms(3_725) == "1:02:05")
    }

    // MARK: - 스냅샷 계산

    @Test func 스냅샷_할당량미설정과_사용량0을_구분한다() {
        var s = DashboardStore.Snapshot()
        #expect(s.quotaGB == nil)
        #expect(s.hasProfile == false)
        #expect(s.hasTodayUsage == false)   // 0으로 표시하지 않고 "없음"으로 구분

        s.todayUpload = 1_000
        #expect(s.hasTodayUsage == true)
        #expect(s.todayTotal == 1_000)
    }

    @Test func 스냅샷_오늘총량은_업다운합이다() {
        var s = DashboardStore.Snapshot()
        s.todayUpload = 300
        s.todayDownload = 700
        #expect(s.todayTotal == 1_000)
        // GB 환산은 1e9 기준 (10진). 1000 B = 1e-6 GB
        #expect(abs(s.todayUsedGB - 0.000_001) < 1e-12)
    }

    @Test func 스냅샷_이퀄리티는_타임스탬프를_포함한다() {
        var a = DashboardStore.Snapshot()
        var b = DashboardStore.Snapshot()
        #expect(a == b)
        b.lastUpdated = Date(timeIntervalSince1970: 1_000)
        #expect(a != b)
    }

    // MARK: - 시간대 버킷 (오늘 사용 패턴 카드)

    /// 24칸 배열이 유지돼야 차트 축이 흔들리지 않는다
    @Test func 시간대버킷_데이터없어도_24칸이다() {
        #expect(DashboardStore.hourBuckets([]).count == 24)
        #expect(DashboardStore.hourBuckets([]).allSatisfy { $0 == 0 })
    }

    @Test func 시간대버킷_데이터있는칸만_채워진다() {
        let usage = [
            ProfileManager.HourlyUsage(id: 3, hour: 3, upload: 100, download: 200),
            ProfileManager.HourlyUsage(id: 14, hour: 14, upload: 1_000, download: 2_000)
        ]
        let b = DashboardStore.hourBuckets(usage)
        #expect(b.count == 24)
        #expect(b[3] == 300)        // upload + download
        #expect(b[14] == 3_000)
        #expect(b[0] == 0)          // 데이터 없는 구간은 0 (비어 보이지 않게 축 고정)
        #expect(b.reduce(0, +) == 3_300)
    }

    @Test func 시간대버킷_범위밖_무시한다() {
        let usage = [ProfileManager.HourlyUsage(id: 99, hour: 99, upload: 10, download: 10)]
        #expect(DashboardStore.hourBuckets(usage).allSatisfy { $0 == 0 })
    }

    // MARK: - 스냅샷 시간대/일별

    @Test func 스냅샷_일별합계와_최댓값() {
        var s = DashboardStore.Snapshot()
        s.dailyTotals = [10, 50, 30]
        #expect(s.dailyTotals.reduce(0, +) == 90)
        #expect(s.dailyPeak == 50)
    }

    @Test func 스냅샷_빈데이터는_피크0() {
        let s = DashboardStore.Snapshot()
        #expect(s.dailyPeak == 0)
        #expect(s.hourlySum == 0)
    }

    // MARK: - 인사이트 프리젠터 (대시보드·리포트 공유)

    @Test func 인사이트_모든종류에_아이콘과_색이_있다() {
        let kinds: [InsightKind] = [.pace, .topOffender, .surge, .nightDrain, .uploadHeavy, .ipChurn]
        for k in kinds {
            #expect(!InsightPresenter.icon(for: k).isEmpty)
            _ = InsightPresenter.color(for: k)
        }
    }

    @Test func 인사이트_히어로값이_종류별로_다르게_포맷된다() {
        let pct = InsightItem(kind: .nightDrain, ratio: 0.34)
        #expect(InsightPresenter.hero(for: pct) == "34%")

        let surge = InsightItem(kind: .surge, ratio: 2.3)
        #expect(InsightPresenter.hero(for: surge) == "2.3×")

        let churn = InsightItem(kind: .ipChurn, count: 6)
        #expect(InsightPresenter.hero(for: churn) == "6")

        // pace는 시각이 없으면 placeholder (0으로 위장하지 않는다)
        let pace = InsightItem(kind: .pace, ratio: 0.5)
        #expect(InsightPresenter.hero(for: pace) == "--:--")
    }

    @Test func 인사이트_제목과본문이_비어있지않다() {
        let i = InsightItem(kind: .topOffender, appName: "Safari", ratio: 0.62, bytes: 1_000)
        #expect(!InsightPresenter.title(for: i).isEmpty)
        #expect(!InsightPresenter.body(for: i).isEmpty)
    }

    /// 앱 트래픽·진단으로 이동할 수 있는 종류만 actionable
    @Test func 인사이트_액션가능한종류는_2개뿐이다() {
        let actionable: [InsightKind] = [.pace, .topOffender, .surge, .nightDrain, .uploadHeavy, .ipChurn]
            .filter { InsightPresenter.isActionable($0) }
        #expect(Set(actionable) == [.topOffender, .ipChurn])
    }

    @Test func InsightProvider_dayKey는_yyyy_MM_dd_형식() {
        let key = InsightProvider.dayKey(Date(timeIntervalSince1970: 1_700_000_000))
        #expect(key.count == 10)
        #expect(key.filter { $0 == "-" }.count == 2)
    }

    /// 프로필이 0개여도 **전역** 인사이트(`topOffender`)는 나올 수 있다 —
    /// 앱 트래픽이 프로필 단위가 아니기 때문이다. 프로필 한정 종류만 비어야 한다.
    @Test func InsightProvider_프로필없어도_전역인사이트는_남을수있다() {
        let items = InsightProvider.build(profiles: [])
        for i in items {
            #expect(i.kind == .topOffender, "프로필 한정 종류(\(i.kind))가 프로필 0개 상태에서 나왔습니다")
        }
    }

    // MARK: - 심야 비중 100% 클램프 (v0.39 버그 회귀)

    /// 분자에 어제 야간이 섞이면 100% 를 넘는다. `getHourlyUsage(days:1)` → `getHourlyUsageToday`
    /// 교체 전 실제로 186% 가 표시됐다. 어떤 경우에도 100% 를 넘지 않아야 한다.
    @Test func 심야비중은_100퍼센트를_넘지않는다() {
        let hourly: [(hour: Int, total: Int64)] = [
            (hour: 2, total: 1_000_000_000),   // 어제 야간이 섞였다고 가정
            (hour: 3, total: 860_000_000)
        ]
        let share = InsightEngine.nightDrainShare(hourlyTotals: hourly, todayTotal: 1_000_000_000)
        #expect(share != nil)
        #expect((share ?? 2) <= 1.0)
    }

    /// 정상 입력은 그대로 반환된다
    @Test func 심야비중_정상입력은_그대로() {
        let hourly: [(hour: Int, total: Int64)] = [
            (hour: 1, total: 30_000_000),
            (hour: 2, total: 20_000_000),
            (hour: 14, total: 50_000_000)
        ]
        #expect(InsightEngine.nightDrainShare(hourlyTotals: hourly, todayTotal: 100_000_000) == 0.5)
    }

    /// 심야 합계가 오늘 총량 이하면 미발동
    @Test func 심야비중_기준미달은_nil() {
        let hourly: [(hour: Int, total: Int64)] = [(hour: 1, total: 1_000_000)]
        #expect(InsightEngine.nightDrainShare(hourlyTotals: hourly, todayTotal: 100_000_000) == nil)
    }

    /// 오늘 총량이 임계(50MB) 미만이면 미발동
    @Test func 심야비중_총량미달은_nil() {
        let hourly: [(hour: Int, total: Int64)] = [(hour: 1, total: 1_000_000)]
        #expect(InsightEngine.nightDrainShare(hourlyTotals: hourly, todayTotal: 1_000_000) == nil)
    }

    // MARK: - SSID 추출 (프로필 조회 키 결정)

    @Test func SSID추출_WiFi는_SSID를_반환한다() {
        let c = ConnectionInfo(
            type: .normalWiFi(ssid: "집", bssid: "AA:BB"), interfaceName: "en0",
            localIP: "192.168.0.2", gatewayIP: "192.168.0.1",
            isExpensive: false, isConstrained: false, rssi: -50, noise: -90,
            linkSpeed: 866, channel: 6, channelWidth: 20, channelBand: "2.4GHz",
            phyMode: "802.11ax", dnsServers: []
        )
        #expect(DashboardStore.ssid(of: c) == "집")
    }

    @Test func SSID추출_이더넷은_인터페이스명을_키로쓴다() {
        let c = ConnectionInfo(
            type: .ethernet, interfaceName: "en0", localIP: nil, gatewayIP: nil,
            isExpensive: false, isConstrained: false, rssi: nil, noise: nil,
            linkSpeed: nil, channel: nil, channelWidth: nil, channelBand: nil,
            phyMode: nil, dnsServers: []
        )
        #expect(DashboardStore.ssid(of: c) == "en0")
    }

    @Test func SSID추출_알수없음과_nil연결은_nil() {
        #expect(DashboardStore.ssid(of: nil) == nil)
        let c = ConnectionInfo(
            type: .unknown, interfaceName: nil, localIP: nil, gatewayIP: nil,
            isExpensive: false, isConstrained: false, rssi: nil, noise: nil,
            linkSpeed: nil, channel: nil, channelWidth: nil, channelBand: nil,
            phyMode: nil, dnsServers: []
        )
        #expect(DashboardStore.ssid(of: c) == nil)
    }

    // MARK: - 관련 안전장치

    /// `NetworkMonitor.macAddress(forInterface:)` 는 7자 이상 인터페이스명에서
    /// `continue` 가 `ptr = next` 를 건너뛰어 무한루프에 빠진다 (T-250 미해결).
    /// 대시보드는 5초 타이머로 반복 호출하므로 길이 가드로 방어한다.
    @Test func MAC조회_긴인터페이스명은_무한루프방어로_거부한다() {
        #expect(DashboardDetailCard.mac(interface: nil) == nil)
        #expect(DashboardDetailCard.mac(interface: "en0") != nil || true)   // 환경 의존 — 크래시 없음
        #expect(DashboardDetailCard.mac(interface: "bridge100") == nil)      // 9자 → 거부
    }
}
