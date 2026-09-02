import Foundation

final class SettingsManager: @unchecked Sendable {
    static let shared = SettingsManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "showTotalColumn": true,
            "menuBarMode": MenuBarMode.speedAndTotal.rawValue,
            "showSSIDInMenuBar": false,
            "showBSSIDInMenuBar": false,
            "showLinkSpeedInMenuBar": false,
            "showDNSInMenuBar": false,
            "menuBarRefreshInterval": Self.defaultMenuBarRefreshInterval,
            "cacheRefreshInterval": Self.defaultCacheRefreshInterval,
            "trafficMonitorInterval": Self.defaultTrafficMonitorInterval,
            "pingInterval": Self.defaultPingInterval,
            "pingLatencyNotificationEnabled": true,
            "autoSwitchProfile": true,
            "floatingShowAtLaunch": false,
            "floatingOpacity": 0.9,
            "floatingShowTraffic": true,
            "floatingShowUsage": true
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

    enum MenuBarMode: String, CaseIterable {
        case speedOnly = "speed"
        case speedAndTotal = "speed_total"
        case speedAndSSID = "speed_ssid"
    }

    var menuBarMode: MenuBarMode {
        get {
            if let raw = defaults.string(forKey: "menuBarMode"),
               let mode = MenuBarMode(rawValue: raw) { return mode }
            return .speedAndTotal
        }
        set { defaults.set(newValue.rawValue, forKey: "menuBarMode") }
    }

    var showSSIDInMenuBar: Bool {
        get { defaults.bool(forKey: "showSSIDInMenuBar") }
        set { defaults.set(newValue, forKey: "showSSIDInMenuBar") }
    }

    var showBSSIDInMenuBar: Bool {
        get { defaults.bool(forKey: "showBSSIDInMenuBar") }
        set { defaults.set(newValue, forKey: "showBSSIDInMenuBar") }
    }

    var showLinkSpeedInMenuBar: Bool {
        get { defaults.bool(forKey: "showLinkSpeedInMenuBar") }
        set { defaults.set(newValue, forKey: "showLinkSpeedInMenuBar") }
    }

    var showDNSInMenuBar: Bool {
        get { defaults.bool(forKey: "showDNSInMenuBar") }
        set { defaults.set(newValue, forKey: "showDNSInMenuBar") }
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

    var floatingShowTraffic: Bool {
        get { defaults.bool(forKey: "floatingShowTraffic") }
        set { defaults.set(newValue, forKey: "floatingShowTraffic") }
    }

    var floatingShowUsage: Bool {
        get { defaults.bool(forKey: "floatingShowUsage") }
        set { defaults.set(newValue, forKey: "floatingShowUsage") }
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
