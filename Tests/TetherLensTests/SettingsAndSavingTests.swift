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
        #expect(s.menuBarMode == .speedAndTotal)
        #expect(s.showSSIDInMenuBar == false)
        #expect(s.menuBarFontSize == SettingsManager.defaultMenuBarFontSize)
        #expect(s.menuBarRefreshInterval == SettingsManager.defaultMenuBarRefreshInterval)
        #expect(s.cacheRefreshInterval == SettingsManager.defaultCacheRefreshInterval)
        #expect(s.trafficMonitorInterval == SettingsManager.defaultTrafficMonitorInterval)
        #expect(s.pingInterval == SettingsManager.defaultPingInterval)
        #expect(s.pingLatencyNotificationEnabled == true)
        #expect(s.autoSwitchProfile == true)
    }

    @Test func 값_저장_조회() {
        let s = makeManager()
        s.showTotalColumn = false
        s.menuBarMode = .speedOnly
        s.menuBarFontSize = 12
        #expect(s.showTotalColumn == false)
        #expect(s.menuBarMode == .speedOnly)
        #expect(s.menuBarFontSize == 12)
    }

    @Test func 잘못된_메뉴바_모드_기본_폴백() {
        let suite = "test-settings-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        d.set("invalid_mode", forKey: "menuBarMode")
        let s = SettingsManager(defaults: d)
        #expect(s.menuBarMode == .speedAndTotal)
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

    @Test func MenuBarMode_모든_케이스() {
        #expect(SettingsManager.MenuBarMode.allCases.count == 3)
        #expect(SettingsManager.MenuBarMode(rawValue: "speed") == .speedOnly)
        #expect(SettingsManager.MenuBarMode(rawValue: "speed_total") == .speedAndTotal)
        #expect(SettingsManager.MenuBarMode(rawValue: "speed_ssid") == .speedAndSSID)
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
