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
    @State private var showBSSIDInMenuBar: Bool
    @State private var showLinkSpeedInMenuBar: Bool
    @State private var showDNSInMenuBar: Bool
    @State private var autoSwitchProfile: Bool

    @State private var menuBarInterval: Double
    @State private var cacheInterval: Double
    @State private var trafficInterval: Double
    @State private var pingInterval: Double
    @State private var fontSize: Double
    @State private var showAppTraffic: Bool
    @State private var floatingShowAtLaunch: Bool
    @State private var floatingOpacity: Double
    @State private var floatingShowTraffic: Bool
    @State private var floatingShowUsage: Bool
    @State private var notiAuthorized = false
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var locationDiagnostics: [String] = []
    @State private var autoRules: [AutomationRule] = []
    @State private var showAddRule = false
    @State private var ruleName = ""
    @State private var ruleSSID = ""
    @State private var ruleTriggerRaw = AutomationRule.TriggerType.onConnect.rawValue
    @State private var ruleActionRaw = AutomationRule.ActionType.launchApp.rawValue
    @State private var ruleTarget = ""
    @State private var selectedTab = 0

    init() {
        let s = SettingsManager.shared
        _showTotalColumn = State(initialValue: s.showTotalColumn)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        _menuBarModeRaw = State(initialValue: s.menuBarMode.rawValue)
        _showSSIDInMenuBar = State(initialValue: s.showSSIDInMenuBar)
        _showBSSIDInMenuBar = State(initialValue: s.showBSSIDInMenuBar)
        _showLinkSpeedInMenuBar = State(initialValue: s.showLinkSpeedInMenuBar)
        _showDNSInMenuBar = State(initialValue: s.showDNSInMenuBar)
        _autoSwitchProfile = State(initialValue: s.autoSwitchProfile)
        _menuBarInterval = State(initialValue: s.menuBarRefreshInterval)
        _cacheInterval = State(initialValue: s.cacheRefreshInterval)
        _trafficInterval = State(initialValue: s.trafficMonitorInterval)
        _pingInterval = State(initialValue: s.pingInterval)
        _fontSize = State(initialValue: s.menuBarFontSize)
        _showAppTraffic = State(initialValue: UserDefaults.standard.object(forKey: "popover_show_app_traffic") as? Bool ?? true)
        _floatingShowAtLaunch = State(initialValue: s.floatingShowAtLaunch)
        _floatingOpacity = State(initialValue: s.floatingOpacity)
        _floatingShowTraffic = State(initialValue: s.floatingShowTraffic)
        _floatingShowUsage = State(initialValue: s.floatingShowUsage)
        _autoRules = State(initialValue: AutomationManager.shared.rules)
    }

    private var menuBarOptions: [(String, Double)] { Localized.menuBarIntervalOptions }
    private var cacheOptions: [(String, Double)] { Localized.cacheIntervalOptions }
    private var trafficOptions: [(String, Double)] { Localized.trafficIntervalOptions }
    private var pingOptions: [(String, Double)] { Localized.pingIntervalOptions }

    var body: some View {
        // 맥 설정 앱 컨벤션 (macos-app-design §17): 상단 탭 + Form(.grouped) 섹션 카드 + 닫기 버튼 없음
        TabView(selection: $selectedTab) {
            menuBarTab
                .tabItem { Label(Localized.menuBar, systemImage: "menubar.rectangle") }
                .tag(0)
            permissionsTab
                .tabItem { Label(Localized.permissions, systemImage: "lock.shield") }
                .tag(1)
            notificationsTab
                .tabItem { Label(Localized.notifications, systemImage: "bell") }
                .tag(2)
            performanceTab
                .tabItem { Label(Localized.performance, systemImage: "gauge.with.dots.needle.bottom.50percent") }
                .tag(3)
            automationTab
                .tabItem { Label(Localized.automationTitle, systemImage: "bolt") }
                .tag(4)
        }
        .frame(width: TLSize.settingsWindow.w, height: TLSize.settingsWindow.h)
        .onAppear {
            refreshPermissions()
            pinWindowTitle()
        }
        .onChange(of: selectedTab) { _, _ in
            pinWindowTitle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didUpdateNotification)) { note in
            guard let win = note.object as? NSWindow, win.isVisible, win.title != Localized.settings else { return }
            win.title = Localized.settings
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onDisappear {
            applyPollingIntervals()
        }
    }

    // Settings scene은 TabView 선택 탭 이름이 창 제목에 반영되므로 "설정"으로 고정 (v0.30)
    private func pinWindowTitle() {
        DispatchQueue.main.async {
            guard let win = NSApp.keyWindow, win.title != Localized.settings else { return }
            win.title = Localized.settings
        }
    }

    // MARK: - 메뉴바

    private var menuBarTab: some View {
        Form {
            Section(Localized.menuBar) {
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

                Toggle(Localized.showBSSIDInMenuBar, isOn: $showBSSIDInMenuBar)
                    .onChange(of: showBSSIDInMenuBar) { _, newValue in
                        SettingsManager.shared.showBSSIDInMenuBar = newValue
                        NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                    }

                Toggle(Localized.showLinkSpeedInMenuBar, isOn: $showLinkSpeedInMenuBar)
                    .onChange(of: showLinkSpeedInMenuBar) { _, newValue in
                        SettingsManager.shared.showLinkSpeedInMenuBar = newValue
                        NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                    }

                Toggle(Localized.showDNSInMenuBar, isOn: $showDNSInMenuBar)
                    .onChange(of: showDNSInMenuBar) { _, newValue in
                        SettingsManager.shared.showDNSInMenuBar = newValue
                        NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                    }
            }

            Section(Localized.general) {
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

            Section(Localized.fontSize) {
                HStack {
                    Text(Localized.defaultParen(Int(SettingsManager.defaultMenuBarFontSize)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $fontSize, in: 7...14, step: 1,
                           onEditingChanged: { editing in
                        if !editing {
                            SettingsManager.shared.menuBarFontSize = fontSize
                            NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                        }
                    })
                    Text("\(Int(fontSize))pt")
                        .font(.caption).monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }

                Picker(Localized.showAppTrafficLabel, selection: $showAppTraffic) {
                    Text(Localized.show).tag(true)
                    Text(Localized.hide).tag(false)
                }
                .onChange(of: showAppTraffic) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "popover_show_app_traffic")
                }
            }

            Section(Localized.floatingWindow) {
                Toggle(Localized.floatingAtLaunch, isOn: $floatingShowAtLaunch)
                    .onChange(of: floatingShowAtLaunch) { _, newValue in
                        SettingsManager.shared.floatingShowAtLaunch = newValue
                    }

                Toggle(Localized.floatingShowTraffic, isOn: $floatingShowTraffic)
                    .onChange(of: floatingShowTraffic) { _, newValue in
                        SettingsManager.shared.floatingShowTraffic = newValue
                        NotificationCenter.default.post(name: .init("floatingSettingsChanged"), object: nil)
                    }

                Toggle(Localized.floatingShowUsage, isOn: $floatingShowUsage)
                    .onChange(of: floatingShowUsage) { _, newValue in
                        SettingsManager.shared.floatingShowUsage = newValue
                    }

                HStack {
                    Text(Localized.floatingOpacity)
                        .font(.body)
                    Spacer()
                    Slider(value: $floatingOpacity, in: 0.35...1.0)
                        .frame(width: 160)
                        .onChange(of: floatingOpacity) { _, newValue in
                            SettingsManager.shared.floatingOpacity = newValue
                        }
                    Text("\(Int(floatingOpacity * 100))%")
                        .font(.caption).monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 권한

    private var permissionsTab: some View {
        Form {
            Section(Localized.locationPermission) {
                HStack {
                    if locationStatus == .authorized || locationStatus == .authorizedAlways {
                        Label(Localized.notificationAuthorized, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(TLPalette.success)
                    } else {
                        Text(locationStatus == .denied ? Localized.denied : Localized.notDetermined)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(Localized.requestPermission) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                if locationStatus == .authorized || locationStatus == .authorizedAlways {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(locationDiagnostics, id: \.self) { line in
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section(Localized.notifications) {
                HStack {
                    if notiAuthorized {
                        Label(Localized.notificationAuthorized, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(TLPalette.success)
                    } else {
                        Text(Localized.denied)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(Localized.requestPermission) {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                                DispatchQueue.main.async { notiAuthorized = granted }
                            }
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?com.tetherlens.app") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 알림

    private var notificationsTab: some View {
        Form {
            Section(Localized.quotaAlert) {
                Text(Localized.string("50%, 80%, 95%, 100% 자동 알림", "50%, 80%, 95%, 100% auto"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(Localized.latencyAlert) {
                Toggle(Localized.defaultShown, isOn: Binding(
                    get: { SettingsManager.shared.pingLatencyNotificationEnabled },
                    set: { SettingsManager.shared.pingLatencyNotificationEnabled = $0 }
                ))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 성능

    private var performanceTab: some View {
        Form {
            Section {
                pollingRow(label: Localized.menuBarRefresh, defaultValue: SettingsManager.defaultMenuBarRefreshInterval, selection: $menuBarInterval, options: menuBarOptions)
                pollingRow(label: Localized.cacheRefresh, defaultValue: SettingsManager.defaultCacheRefreshInterval, selection: $cacheInterval, options: cacheOptions)
                pollingRow(label: Localized.trafficRefresh, defaultValue: SettingsManager.defaultTrafficMonitorInterval, selection: $trafficInterval, options: trafficOptions)
                pollingRow(label: Localized.pingIntervalLabel, defaultValue: SettingsManager.defaultPingInterval, selection: $pingInterval, options: pingOptions)
            } header: {
                Text(Localized.performance)
            } footer: {
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
                .foregroundStyle(TLPalette.download)
                .disabled(SettingsManager.shared.isUsingDefaultPollingIntervals)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 자동화

    private var automationTab: some View {
        Form {
            Section(Localized.automationTitle) {
                if autoRules.isEmpty {
                    Text(Localized.automationEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(autoRules) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name)
                                .font(.caption).bold()
                            Text(rule.summary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { newValue in setRule(rule, enabled: newValue) }
                        ))
                        .labelsHidden()
                        .controlSize(.small)
                        Button(Localized.delete) { removeRule(rule) }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(TLPalette.danger)
                    }
                }

                if showAddRule {
                    TextField(Localized.automationRuleName, text: $ruleName)
                        .textFieldStyle(.roundedBorder)
                    TextField(Localized.automationSSID, text: $ruleSSID)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Picker(Localized.automationTrigger, selection: $ruleTriggerRaw) {
                            ForEach(AutomationRule.TriggerType.allCases) { t in
                                Text(t.label).tag(t.rawValue)
                            }
                        }
                        Picker(Localized.automationAction, selection: $ruleActionRaw) {
                            ForEach(AutomationRule.ActionType.allCases) { a in
                                Text(a.label).tag(a.rawValue)
                            }
                        }
                    }
                    TextField(Localized.automationTarget, text: $ruleTarget)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(Localized.automationAdd) { addRule() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button(Localized.cancel) { resetRuleForm() }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                    }
                }

                Button(showAddRule ? Localized.cancel : Localized.automationNewRule) {
                    if showAddRule { resetRuleForm() } else { showAddRule = true }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(TLPalette.download)
            }
        }
        .formStyle(.grouped)
    }

    private func pollingRow(label: String, defaultValue: Double, selection: Binding<Double>, options: [(String, Double)]) -> some View {
        HStack {
            Text(label)
                .font(.body)
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

    private func addRule() {
        let name = ruleName.trimmingCharacters(in: .whitespaces)
        let ssid = ruleSSID.trimmingCharacters(in: .whitespaces)
        guard !ssid.isEmpty else { return }
        var rule = AutomationRule(name: name.isEmpty ? ssid : name, ssid: ssid,
                                  trigger: AutomationRule.TriggerType(rawValue: ruleTriggerRaw) ?? .onConnect,
                                  action: AutomationRule.ActionType(rawValue: ruleActionRaw) ?? .launchApp,
                                  target: ruleTarget.trimmingCharacters(in: .whitespaces))
        AutomationManager.shared.save(rule)
        autoRules = AutomationManager.shared.rules
        resetRuleForm()
    }

    private func setRule(_ rule: AutomationRule, enabled: Bool) {
        var updated = rule
        updated.isEnabled = enabled
        AutomationManager.shared.save(updated)
        autoRules = AutomationManager.shared.rules
    }

    private func removeRule(_ rule: AutomationRule) {
        AutomationManager.shared.delete(rule)
        autoRules = AutomationManager.shared.rules
    }

    private func resetRuleForm() {
        showAddRule = false
        ruleName = ""
        ruleSSID = ""
        ruleTriggerRaw = AutomationRule.TriggerType.onConnect.rawValue
        ruleActionRaw = AutomationRule.ActionType.launchApp.rawValue
        ruleTarget = ""
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
