import Testing
import Foundation
@testable import TetherLens

@Suite struct SettingsManagerTests {

    private func makeManager() -> SettingsManager {
        let suite = "test-settings-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return SettingsManager(defaults: d)
    }

    @Test func 기본_설정값() {
        let s = makeManager()
        #expect(s.showTotalColumn == true)
        #expect(s.showLatency == true)
        #expect(s.showRSSI == true)
        #expect(s.menuBarFontSize == SettingsManager.defaultMenuBarFontSize)
        #expect(s.menuBarRefreshInterval == SettingsManager.defaultMenuBarRefreshInterval)
        #expect(s.cacheRefreshInterval == SettingsManager.defaultCacheRefreshInterval)
        #expect(s.trafficMonitorInterval == SettingsManager.defaultTrafficMonitorInterval)
        #expect(s.pingInterval == SettingsManager.defaultPingInterval)
        #expect(s.pingLatencyNotificationEnabled == true)
        #expect(s.autoSwitchProfile == true)
    }

    @Test func 그래프_토글_기본값_CPU_GPU_OFF_메모리_ON() {
        let s = makeManager()
        #expect(s.showCPUGraph == false)
        #expect(s.showGPUGraph == false)
        #expect(s.showMemGraph == true)
    }

    @Test func 그래프_토글_저장_조회() {
        let s = makeManager()
        s.showCPUGraph = true
        s.showGPUGraph = true
        s.showMemGraph = false
        #expect(s.showCPUGraph == true)
        #expect(s.showGPUGraph == true)
        #expect(s.showMemGraph == false)
    }

    @Test func 값_저장_조회() {
        let s = makeManager()
        s.showTotalColumn = false
        s.showLatency = false
        s.showRSSI = false
        s.menuBarFontSize = 12
        #expect(s.showTotalColumn == false)
        #expect(s.showLatency == false)
        #expect(s.showRSSI == false)
        #expect(s.menuBarFontSize == 12)
    }

    @Test func 지연_RSSI_기본_폴백() {
        let suite = "test-settings-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        d.set(false, forKey: "showLatency")
        d.set(false, forKey: "showRSSI")
        let s = SettingsManager(defaults: d)
        #expect(s.showLatency == false)
        #expect(s.showRSSI == false)
    }

    // MARK: - 대시보드 카드 토글 (v0.39)

    /// 설정 화면이 처음 열렸을 때 9칸이 전부 켜져 있어야 한다 (토글 안 누르고 창만 닫아도 상태가 바뀌면 안 됨)
    @Test func 카드_토글_기본값은_전부_ON() {
        let s = makeManager()
        for card in DashboardCard.ordered {
            #expect(s.isCardEnabled(card) == true)
        }
    }

    @Test func 카드_토글_저장_조회() {
        let s = makeManager()
        s.setCardEnabled(.cpu, false)
        s.setCardEnabled(.process, false)
        #expect(s.isCardEnabled(.cpu) == false)
        #expect(s.isCardEnabled(.process) == false)
        // 다른 카드는 영향받지 않는다 (키가 카드별로 격리됨)
        #expect(s.isCardEnabled(.gpu) == true)
        #expect(s.isCardEnabled(.memory) == true)
    }

    /// "모든 카드 표시" 버튼은 꺼진 카드를 전부 되돌린다
    @Test func 모든카드표시_동작() {
        let s = makeManager()
        for card in DashboardCard.ordered { s.setCardEnabled(card, false) }
        for card in DashboardCard.ordered { s.setCardEnabled(card, true) }
        for card in DashboardCard.ordered {
            #expect(s.isCardEnabled(card) == true)
        }
    }

    /// 행 전체가 OFF 면 그 행이 사라지므로, 한 행의 두 카드는 서로 독립적으로 꺼야 한다
    @Test func 같은행의_두카드는_독립적으로_토글된다() {
        let s = makeManager()
        let firstRow = DashboardCard.rows[0]
        #expect(firstRow.count == 2)
        s.setCardEnabled(firstRow[0], false)
        #expect(s.isCardEnabled(firstRow[0]) == false)
        #expect(s.isCardEnabled(firstRow[1]) == true)
    }

    /// 새 인스턴스로도 유지되어야 한다 (앱 재실행 후 설정이 살아있어야 함)
    @Test func 카드_토글은_새인스턴스에서도_유지된다() {
        let suite = "test-settings-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        SettingsManager(defaults: d).setCardEnabled(.insight, false)
        #expect(SettingsManager(defaults: d).isCardEnabled(.insight) == false)
    }

    // MARK: - 프로세스 리스트 실시간 구간 (v0.39)

    /// 창을 보고 있을 때만 짧은 구간을 쓴다 — 기본값은 2초
    @Test func 프로세스리스트_구간_기본값은_2초() {
        let s = makeManager()
        #expect(s.processListInterval == 2.0)
        #expect(SettingsManager.defaultProcessListInterval == 2.0)
    }

    /// 배터리 보호: 창을 안 볼 때는 기존 10초 주기를 그대로 쓴다
    @Test func 트래픽_기본주기는_10초로_유지된다() {
        let s = makeManager()
        #expect(s.trafficMonitorInterval == 10.0)
        #expect(s.processListInterval < s.trafficMonitorInterval)
    }

    @Test func 프로세스리스트_구간_저장_조회() {
        let s = makeManager()
        s.processListInterval = 3
        #expect(s.processListInterval == 3)
    }

    /// 0 을 넣으면 0 으로 나누게 되므로 기본값으로 되돌린다
    @Test func 프로세스리스트_구간이_0이면_기본값으로_복원() {
        let s = makeManager()
        s.processListInterval = 0
        #expect(s.processListInterval == SettingsManager.defaultProcessListInterval)
    }

    @Test func resetPollingIntervals_기본값_복원() {
        let s = makeManager()
        s.menuBarRefreshInterval = 10
        s.cacheRefreshInterval = 20
        s.trafficMonitorInterval = 30
        s.pingInterval = 40
        #expect(!s.isUsingDefaultPollingIntervals)

        s.resetPollingIntervals()
        #expect(s.menuBarRefreshInterval == SettingsManager.defaultMenuBarRefreshInterval)
        #expect(s.cacheRefreshInterval == SettingsManager.defaultCacheRefreshInterval)
        #expect(s.trafficMonitorInterval == SettingsManager.defaultTrafficMonitorInterval)
        #expect(s.pingInterval == SettingsManager.defaultPingInterval)
        #expect(s.isUsingDefaultPollingIntervals)
    }
}

@Suite struct SavingModeManagerTests {

    private func makeManager() -> SavingModeManager {
        let suite = "test-saving-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return SavingModeManager(defaults: d)
    }

    @Test func 절약모드_임계값_단일화() {
        let s = makeManager()
        #expect(!s.isEnabled)
        #expect(s.greenThreshold == 0.6)
        #expect(s.orangeThreshold == 0.85)

        s.isEnabled = true
        #expect(s.greenThreshold == 0.4)
        #expect(s.orangeThreshold == 0.65)

        s.isEnabled = false
        #expect(s.greenThreshold == 0.6)
    }

    @Test func shouldAutoActivate_조건() {
        let s = makeManager()
        s.autoActivate = true
        #expect(s.shouldAutoActivate(used: 8, quota: 10) == true)
        #expect(s.shouldAutoActivate(used: 7, quota: 10) == false)
        #expect(s.shouldAutoActivate(used: 100, quota: 0) == false, "할당량 0이면 비활성")

        s.autoActivate = false
        #expect(s.shouldAutoActivate(used: 9, quota: 10) == false, "자동 활성 꺼짐이면 비활성")
    }
}
