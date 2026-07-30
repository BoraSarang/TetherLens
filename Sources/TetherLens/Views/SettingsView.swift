import SwiftUI
import ServiceManagement
import UserNotifications
import CoreLocation
import CoreWLAN

struct SettingsView: View {
    @State private var showTotalColumn: Bool
    @State private var launchAtLogin: Bool

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
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        Toggle(Localized.showTotalInMenuBar, isOn: $showTotalColumn)
                            .onChange(of: showTotalColumn) { _, newValue in
                                SettingsManager.shared.showTotalColumn = newValue
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
                    }
                    .padding(.horizontal, 20)

                    Divider().padding(.horizontal, 12)

                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Localized.menuBar)
                                .font(.subheadline).bold()
                            HStack {
                                Text(Localized.fontSize)
                                    .font(.caption)
                                Text(Localized.defaultParen(Int(SettingsManager.defaultMenuBarFontSize)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Slider(value: $fontSize, in: 7...14, step: 1)
                                    .frame(width: 80)
                                    .onChange(of: fontSize) { _, newValue in
                                        SettingsManager.shared.menuBarFontSize = newValue
                                        NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                                    }
                                Text("\(Int(fontSize))pt")
                                    .font(.caption).monospacedDigit()
                                    .frame(width: 28, alignment: .trailing)
                            }
                            .padding(.leading, 12)
                            HStack {
                                Text(Localized.showAppTrafficLabel)
                                    .font(.caption)
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
                            .padding(.leading, 12)
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider().padding(.horizontal, 12)

                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Localized.permissions)
                                .font(.subheadline).bold()
                            HStack {
                                Text(Localized.locationPermission)
                                    .font(.caption)
                                Spacer()
                                if locationStatus == .authorized || locationStatus == .authorizedAlways {
                                    Text(Localized.notificationAuthorized)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text(locationStatus == .denied ? Localized.denied : Localized.notDetermined)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Button(Localized.requestPermission) {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.leading, 12)
                            if locationStatus == .authorized || locationStatus == .authorizedAlways {
                                VStack(alignment: .leading, spacing: 1) {
                                    ForEach(locationDiagnostics, id: \.self) { line in
                                        Text(line)
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 12)
                                .padding(.bottom, 4)
                            }
                            HStack {
                                Text(Localized.notifications)
                                    .font(.caption)
                                Spacer()
                                if notiAuthorized {
                                    Text(Localized.notificationAuthorized)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text(Localized.denied)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
                            .padding(.leading, 12)
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider().padding(.horizontal, 12)

                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Localized.notifications)
                                .font(.subheadline).bold()
                            HStack {
                                Text(Localized.quotaAlert)
                                    .font(.caption)
                                Spacer()
                                Text(Localized.string("50%, 80%, 95%, 100% 자동 알림", "50%, 80%, 95%, 100% auto"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 12)
                            Divider()
                            HStack {
                                Text(Localized.latencyAlert)
                                    .font(.caption)
                                Text(Localized.defaultShown)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
                            .padding(.leading, 12)
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider().padding(.horizontal, 12)

                    HStack {
                        Text(Localized.performance)
                            .font(.subheadline).bold()
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
                        .font(.caption)
                        .foregroundColor(.blue)
                        .disabled(SettingsManager.shared.isUsingDefaultPollingIntervals)
                    }
                    .padding(.horizontal, 20)

                    Group {
                        pollingRow(label: Localized.menuBarRefresh, defaultValue: SettingsManager.defaultMenuBarRefreshInterval, selection: $menuBarInterval, options: menuBarOptions)
                        pollingRow(label: Localized.cacheRefresh, defaultValue: SettingsManager.defaultCacheRefreshInterval, selection: $cacheInterval, options: cacheOptions)
                        pollingRow(label: Localized.trafficRefresh, defaultValue: SettingsManager.defaultTrafficMonitorInterval, selection: $trafficInterval, options: trafficOptions)
                        pollingRow(label: Localized.pingIntervalLabel, defaultValue: SettingsManager.defaultPingInterval, selection: $pingInterval, options: pingOptions)
                    }
                    .padding(.leading, 32)
                    .padding(.trailing, 20)
                }
                .padding(.vertical, 12)
            }

            Divider()

            HStack {
                Spacer()
                Button(Localized.close, action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 320, height: 480)
        .onAppear {
            refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onDisappear {
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
    }

    private func pollingRow(label: String, defaultValue: Double, selection: Binding<Double>, options: [(String, Double)]) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            Text(String(format: Localized.string("(기본: %@)", "(Default: %@)"), formatInterval(defaultValue)))
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.1) { opt in
                    Text(opt.0).tag(opt.1)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    private func formatInterval(_ interval: Double) -> String {
        Localized.intervalSec(Int(interval))
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
