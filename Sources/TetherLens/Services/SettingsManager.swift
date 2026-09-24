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
