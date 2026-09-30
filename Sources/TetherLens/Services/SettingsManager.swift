import Foundation

final class SettingsManager: @unchecked Sendable {
    static let shared = SettingsManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "showTotalColumn": true,
            "showLatency": true,
            "showRSSI": true,
            "menuBarRefreshInterval": Self.defaultMenuBarRefreshInterval,
            "cacheRefreshInterval": Self.defaultCacheRefreshInterval,
            "trafficMonitorInterval": Self.defaultTrafficMonitorInterval,
            "pingInterval": Self.defaultPingInterval,
            "pingLatencyNotificationEnabled": true,
            "autoReconnectOnDrop": false,
            "autoSwitchProfile": true,
            "floatingShowAtLaunch": false,
            "floatingOpacity": 0.9,
            "popoverShowResources": true,
            "showCPUGraph": false,
            "showGPUGraph": false,
            "showMemGraph": true
        ])
    }

    static let defaultMenuBarRefreshInterval: Double = 3.0
    static let defaultCacheRefreshInterval: Double = 5.0
    static let defaultTrafficMonitorInterval: Double = 10.0
    /// 요청 1회 측정 시 관측 구간 (초)
    static let defaultProcessListInterval: Double = 3.0
    static let defaultPingInterval: Double = 5.0
    static let defaultMenuBarFontSize: Double = 9.0
    static let defaultQuotaWarningThreshold: Double = 1.0

    var showTotalColumn: Bool {
        get { defaults.bool(forKey: "showTotalColumn") }
        set { defaults.set(newValue, forKey: "showTotalColumn") }
    }

    var showLatency: Bool {
        get { defaults.object(forKey: "showLatency") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showLatency") }
    }

    var showRSSI: Bool {
        get { defaults.object(forKey: "showRSSI") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showRSSI") }
    }

    var menuBarFontSize: Double {
        get { defaults.object(forKey: "menuBarFontSize") as? Double ?? Self.defaultMenuBarFontSize }
        set { defaults.set(newValue, forKey: "menuBarFontSize") }
    }

    var quotaWarningThreshold: Double {
        get { defaults.object(forKey: "quotaWarningThreshold") as? Double ?? Self.defaultQuotaWarningThreshold }
        set { defaults.set(newValue, forKey: "quotaWarningThreshold") }
    }

    var menuBarRefreshInterval: Double {
        get { defaults.double(forKey: "menuBarRefreshInterval") }
        set { defaults.set(newValue, forKey: "menuBarRefreshInterval") }
    }

    var cacheRefreshInterval: Double {
        get { defaults.double(forKey: "cacheRefreshInterval") }
        set { defaults.set(newValue, forKey: "cacheRefreshInterval") }
    }

    var trafficMonitorInterval: Double {
        get { defaults.double(forKey: "trafficMonitorInterval") }
        set { defaults.set(newValue, forKey: "trafficMonitorInterval") }
    }

    /// **상시** 프로세스 트래픽 측정 여부 — 기본 `false`.
    ///
    /// ## 왜 기본으로 꺼 둔다
    ///
    /// `nettop` 은 프로세스별 네트워크의 유일한 소스인데, 이 머신에서
    /// `-l`/`-s` 와 무관하게 **약 135% CPU** 를 쓴다 (2026-09-30 실측).
    /// 켜 두면 nettop 이 사실상 상시 실행되어 배터리를 크게 먹는다.
    ///
    /// 그래서 기본은 끄고, 필요할 때만 **1회 측정**( `TrafficMonitor.measureProcessList` ) 으로
    /// "지금 뭐가 쓰지?" 에 답한다. 켜고 싶으면 사용자가 명시적으로 ON 한다.
    var processListEnabled: Bool {
        get { defaults.object(forKey: "processListEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "processListEnabled") }
    }

    /// 요청 1회 측정 시 관측 구간(초).
    ///
    /// "어? 지금 뭐가 쓰지?" 에는 3초 스냅샷이면 답할 수 있다.
    /// 평상시에는 nettop 이 돌지 않으니 이 값이 배터리 비용에 영향을 주는 건 아니다.
    var processListInterval: Double {
        get {
            let v = defaults.double(forKey: "processListInterval")
            return v > 0 ? v : Self.defaultProcessListInterval
        }
        set { defaults.set(newValue, forKey: "processListInterval") }
    }

    var pingInterval: Double {
        get { defaults.double(forKey: "pingInterval") }
        set { defaults.set(newValue, forKey: "pingInterval") }
    }

    var pingLatencyNotificationEnabled: Bool {
        get { defaults.object(forKey: "pingLatencyNotificationEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "pingLatencyNotificationEnabled") }
    }

    /// 끊김 시 Wi-Fi 자동 재연결 (v0.35, 기본 OFF)
    var autoReconnectOnDrop: Bool {
        get { defaults.object(forKey: "autoReconnectOnDrop") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "autoReconnectOnDrop") }
    }

    var autoSwitchProfile: Bool {
        get { defaults.object(forKey: "autoSwitchProfile") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoSwitchProfile") }
    }

    var floatingShowAtLaunch: Bool {
        get { defaults.bool(forKey: "floatingShowAtLaunch") }
        set { defaults.set(newValue, forKey: "floatingShowAtLaunch") }
    }

    var floatingOpacity: Double {
        get { defaults.object(forKey: "floatingOpacity") as? Double ?? 0.9 }
        set { defaults.set(newValue, forKey: "floatingOpacity") }
    }

    /// 상세 보기 시스템 리소스 섹션 표시 (v0.32.1).
    var popoverShowResources: Bool {
        get { defaults.object(forKey: "popoverShowResources") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "popoverShowResources") }
    }

    /// 개별 카드 표시 — 기본: CPU/GPU OFF, 메모리 ON (v0.37). 네트워크 카드는 항상 표시.
    var showCPUGraph: Bool {
        get { defaults.object(forKey: "showCPUGraph") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showCPUGraph") }
    }

    var showGPUGraph: Bool {
        get { defaults.object(forKey: "showGPUGraph") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showGPUGraph") }
    }

    var showMemGraph: Bool {
        get { defaults.object(forKey: "showMemGraph") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showMemGraph") }
    }

    // MARK: - 대시보드 카드 토글 (v0.39)

    /// 카드 표시 여부 — 기본 ON. 설정을 되돌리면 전부 ON.
    /// (P3에서 설정 UI 추가 예정 — 지금은 키만 존재해 배선해 둔다)
    func isCardEnabled(_ card: DashboardCard) -> Bool {
        defaults.object(forKey: Self.cardKey(card)) as? Bool ?? true
    }

    func setCardEnabled(_ card: DashboardCard, _ enabled: Bool) {
        defaults.set(enabled, forKey: Self.cardKey(card))
    }

    private static func cardKey(_ card: DashboardCard) -> String { "dashboard.card.\(card.rawValue)" }

    func resetPollingIntervals() {
        menuBarRefreshInterval = Self.defaultMenuBarRefreshInterval
        cacheRefreshInterval = Self.defaultCacheRefreshInterval
        trafficMonitorInterval = Self.defaultTrafficMonitorInterval
        pingInterval = Self.defaultPingInterval
    }

    var isUsingDefaultPollingIntervals: Bool {
        menuBarRefreshInterval == Self.defaultMenuBarRefreshInterval
        && cacheRefreshInterval == Self.defaultCacheRefreshInterval
        && trafficMonitorInterval == Self.defaultTrafficMonitorInterval
        && pingInterval == Self.defaultPingInterval
    }
}
