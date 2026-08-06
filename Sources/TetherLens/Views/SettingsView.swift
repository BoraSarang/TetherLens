import SwiftUI
import ServiceManagement
import UserNotifications
import CoreLocation
import CoreWLAN

struct SettingsView: View {
    @State private var showTotalColumn: Bool
    @State private var launchAtLogin: Bool
    @State private var menuBarModeRaw: String
    @State private var showSSIDInMenuBar: Bool
    @State private var autoSwitchProfile: Bool

    @State private var menuBarInterval: Double
    @State private var cacheInterval: Double
    @State private var trafficInterval: Double
    @State private var pingInterval: Double
    @State private var fontSize: Double
    @State private var showAppTraffic: Bool
    @State private var notiAuthorized = false
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var locationDiagnostics: [String] = []

    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let s = SettingsManager.shared
        _showTotalColumn = State(initialValue: s.showTotalColumn)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        _menuBarModeRaw = State(initialValue: s.menuBarMode.rawValue)
        _showSSIDInMenuBar = State(initialValue: s.showSSIDInMenuBar)
        _autoSwitchProfile = State(initialValue: s.autoSwitchProfile)
        _menuBarInterval = State(initialValue: s.menuBarRefreshInterval)
        _cacheInterval = State(initialValue: s.cacheRefreshInterval)
        _trafficInterval = State(initialValue: s.trafficMonitorInterval)
        _pingInterval = State(initialValue: s.pingInterval)
        _fontSize = State(initialValue: s.menuBarFontSize)
        _showAppTraffic = State(initialValue: UserDefaults.standard.object(forKey: "popover_show_app_traffic") as? Bool ?? true)
    }

    private var menuBarOptions: [(String, Double)] { Localized.menuBarIntervalOptions }
    private var cacheOptions: [(String, Double)] { Localized.cacheIntervalOptions }
    private var trafficOptions: [(String, Double)] { Localized.trafficIntervalOptions }
    private var pingOptions: [(String, Double)] { Localized.pingIntervalOptions }

    var body: some View {
        VStack(spacing: 0) {
            Text(Localized.settings)
                .font(TLFont.headline)
                .padding(.top, TLSpace.xxxl)
                .padding(.bottom, TLSpace.xl)
                .frame(maxWidth: .infinity)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: TLSpace.xl) {
                    Group {
                        Toggle(Localized.showTotalInMenuBar, isOn: $showTotalColumn)
                            .onChange(of: showTotalColumn) { _, newValue in
                                SettingsManager.shared.showTotalColumn = newValue
                                NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                            }

                        Picker(Localized.menuBarDisplayMode, selection: $menuBarModeRaw) {
                            ForEach(SettingsManager.MenuBarMode.allCases, id: \.rawValue) { mode in
                                Text(modeLabel(mode)).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: menuBarModeRaw) { _, newValue in
                            if let mode = SettingsManager.MenuBarMode(rawValue: newValue) {
                                SettingsManager.shared.menuBarMode = mode
                                NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                            }
                        }

                        Toggle(Localized.showSSIDInMenuBar, isOn: $showSSIDInMenuBar)
                            .onChange(of: showSSIDInMenuBar) { _, newValue in
                                SettingsManager.shared.showSSIDInMenuBar = newValue
                                NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                            }

                        Toggle(Localized.launchAtLogin, isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                do {
                                    if newValue {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                } catch {
                                    launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }

                        Toggle(Localized.autoSwitchProfile, isOn: $autoSwitchProfile)
                            .onChange(of: autoSwitchProfile) { _, newValue in
                                SettingsManager.shared.autoSwitchProfile = newValue
                                NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                            }
                    }
                    .padding(.horizontal, TLSpace.xxxl)

                    Divider().padding(.horizontal, TLSpace.xl)

                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Localized.menuBar)
                                .font(TLFont.subheadline).bold()
                            HStack {
                                Text(Localized.fontSize)
                                    .font(TLFont.caption)
                                Text(Localized.defaultParen(Int(SettingsManager.defaultMenuBarFontSize)))
                                    .font(TLFont.caption2)
                                    .foregroundColor(TLPalette.textSecondary)
                                Spacer()
                                Slider(value: $fontSize, in: 7...14, step: 1)
                                    .frame(width: 80)
                                    .onChange(of: fontSize) { _, newValue in
                                        SettingsManager.shared.menuBarFontSize = newValue
                                        NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                                    }
                                Text("\(Int(fontSize))pt")
                                    .font(TLFont.caption).monospacedDigit()
                                    .frame(width: 28, alignment: .trailing)
                            }
                            .padding(.leading, TLSpace.xl)
                            HStack {
                                Text(Localized.showAppTrafficLabel)
                                    .font(TLFont.caption)
                                Spacer()
                                Picker("", selection: $showAppTraffic) {
                                    Text(Localized.show).tag(true)
                                    Text(Localized.hide).tag(false)
                                }
                                .pickerStyle(.menu)
                                .fixedSize()
                            }
                            .onChange(of: showAppTraffic) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "popover_show_app_traffic")
                            }
                            .padding(.leading, TLSpace.xl)
                        }
                    }
                    .padding(.horizontal, TLSpace.xxxl)

                    Divider().padding(.horizontal, TLSpace.xl)

                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Localized.permissions)
                                .font(TLFont.subheadline).bold()
                            HStack {
                                Text(Localized.locationPermission)
                                    .font(TLFont.caption)
                                Spacer()
                                if locationStatus == .authorized || locationStatus == .authorizedAlways {
                                    Text(Localized.notificationAuthorized)
                                        .font(TLFont.caption)
                                        .foregroundColor(TLPalette.success)
                                } else {
                                    Text(locationStatus == .denied ? Localized.denied : Localized.notDetermined)
                                        .font(TLFont.caption)
                                        .foregroundColor(TLPalette.textSecondary)
                                    Button(Localized.requestPermission) {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.leading, TLSpace.xl)
                            if locationStatus == .authorized || locationStatus == .authorizedAlways {
                                VStack(alignment: .leading, spacing: 1) {
                                    ForEach(locationDiagnostics, id: \.self) { line in
                                        Text(line)
                                            .font(TLFont.badge)
                                            .foregroundColor(TLPalette.textSecondary)
                                    }
                                }
                                .padding(.leading, TLSpace.xl)
                                .padding(.bottom, TLSpace.xs)
                            }
                            HStack {
                                Text(Localized.notifications)
                                    .font(TLFont.caption)
                                Spacer()
                                if notiAuthorized {
                                    Text(Localized.notificationAuthorized)
                                        .font(TLFont.caption)
                                        .foregroundColor(TLPalette.success)
                                } else {
                                    Text(Localized.denied)
                                        .font(TLFont.caption)
                                        .foregroundColor(TLPalette.textSecondary)
                                    Button(Localized.requestPermission) {
                                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                                            DispatchQueue.main.async { notiAuthorized = granted }
                                        }
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?com.tetherlens.app") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.leading, TLSpace.xl)
                        }
                    }
                    .padding(.horizontal, TLSpace.xxxl)

                    Divider().padding(.horizontal, TLSpace.xl)

                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Localized.notifications)
                                .font(TLFont.subheadline).bold()
                            HStack {
                                Text(Localized.quotaAlert)
                                    .font(TLFont.caption)
                                Spacer()
                                Text(Localized.string("50%, 80%, 95%, 100% 자동 알림", "50%, 80%, 95%, 100% auto"))
                                    .font(TLFont.caption2)
                                    .foregroundColor(TLPalette.textSecondary)
                            }
                            .padding(.leading, TLSpace.xl)
                            Divider()
                            HStack {
                                Text(Localized.latencyAlert)
                                    .font(TLFont.caption)
                                Text(Localized.defaultShown)
                                    .font(TLFont.caption2)
                                    .foregroundColor(TLPalette.textSecondary)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { SettingsManager.shared.pingLatencyNotificationEnabled },
                                    set: { SettingsManager.shared.pingLatencyNotificationEnabled = $0 }
                                )) {
                                    Text(Localized.show).tag(true)
                                    Text(Localized.hide).tag(false)
                                }
                                .pickerStyle(.menu)
                                .fixedSize()
                            }
                            .padding(.leading, TLSpace.xl)
                        }
                    }
                    .padding(.horizontal, TLSpace.xxxl)

                    Divider().padding(.horizontal, TLSpace.xl)

                    HStack {
                        Text(Localized.performance)
                            .font(TLFont.subheadline).bold()
                        Spacer()
                        Button(Localized.resetDefaults) {
                            SettingsManager.shared.resetPollingIntervals()
                            menuBarInterval = SettingsManager.defaultMenuBarRefreshInterval
                            cacheInterval = SettingsManager.defaultCacheRefreshInterval
                            trafficInterval = SettingsManager.defaultTrafficMonitorInterval
                            pingInterval = SettingsManager.defaultPingInterval
                            NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                        }
                        .buttonStyle(.plain)
                        .font(TLFont.caption)
                        .foregroundColor(TLPalette.download)
                        .disabled(SettingsManager.shared.isUsingDefaultPollingIntervals)
                    }
                    .padding(.horizontal, TLSpace.xxxl)

                    Group {
                        pollingRow(label: Localized.menuBarRefresh, defaultValue: SettingsManager.defaultMenuBarRefreshInterval, selection: $menuBarInterval, options: menuBarOptions)
                        pollingRow(label: Localized.cacheRefresh, defaultValue: SettingsManager.defaultCacheRefreshInterval, selection: $cacheInterval, options: cacheOptions)
                        pollingRow(label: Localized.trafficRefresh, defaultValue: SettingsManager.defaultTrafficMonitorInterval, selection: $trafficInterval, options: trafficOptions)
                        pollingRow(label: Localized.pingIntervalLabel, defaultValue: SettingsManager.defaultPingInterval, selection: $pingInterval, options: pingOptions)
                    }
                    .padding(.leading, 32)
                    .padding(.trailing, TLSpace.xxxl)
                }
                .padding(.vertical, TLSpace.xl)
            }

            Divider()

            HStack {
                Spacer()
                Button(Localized.close, action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, TLSpace.xxxl)
            .padding(.vertical, TLSpace.xl)
        }
        .frame(width: TLSize.sheetStandard, height: 480)
        .onAppear {
            refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onDisappear {
            applyPollingIntervals()
        }
    }

    private func pollingRow(label: String, defaultValue: Double, selection: Binding<Double>, options: [(String, Double)]) -> some View {
        HStack {
            Text(label)
                .font(TLFont.caption)
            Text(String(format: Localized.string("(기본: %@)", "(Default: %@)"), formatInterval(defaultValue)))
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.1) { opt in
                    Text(opt.0).tag(opt.1)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .onChange(of: selection.wrappedValue) { _, newValue in
                applyPollingIntervals()
            }
        }
    }

    private func applyPollingIntervals() {
        let s = SettingsManager.shared
        if s.menuBarRefreshInterval != menuBarInterval
            || s.cacheRefreshInterval != cacheInterval
            || s.trafficMonitorInterval != trafficInterval
            || s.pingInterval != pingInterval {
            s.menuBarRefreshInterval = menuBarInterval
            s.cacheRefreshInterval = cacheInterval
            s.trafficMonitorInterval = trafficInterval
            s.pingInterval = pingInterval
            NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
        }
    }

    private func formatInterval(_ interval: Double) -> String {
        Localized.intervalSec(Int(interval))
    }

    private func modeLabel(_ mode: SettingsManager.MenuBarMode) -> String {
        switch mode {
        case .speedOnly: return Localized.menuBarModeSpeedOnly
        case .speedAndTotal: return Localized.menuBarModeSpeedTotal
        case .speedAndSSID: return Localized.menuBarModeSpeedSSID
        }
    }

    private func refreshPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized
            DispatchQueue.main.async { notiAuthorized = authorized }
        }
        let locManager = CLLocationManager()
        locationStatus = locManager.authorizationStatus
        var diag: [String] = []
        diag.append("System Location: \(CLLocationManager.locationServicesEnabled() ? "ON" : "OFF")")
        diag.append("Wi-Fi: \(CWWiFiClient.shared().interface() != nil ? "Present" : "Not Found")")
        if let lat = UserDefaults.standard.object(forKey: "last_latitude") as? Double,
           let lng = UserDefaults.standard.object(forKey: "last_longitude") as? Double {
            diag.append("Cached: \(lat), \(lng)")
        } else {
            diag.append("Cached: None")
        }
        locationDiagnostics = diag
    }
}
