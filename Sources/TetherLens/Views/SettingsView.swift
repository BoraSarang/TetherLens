import SwiftUI
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    @State private var showTotalColumn: Bool
    @State private var launchAtLogin: Bool

    @State private var menuBarInterval: Double
    @State private var cacheInterval: Double
    @State private var trafficInterval: Double
    @State private var pingInterval: Double
    @State private var fontSize: Double
    @State private var quotaThreshold: Double
    @State private var showAppTraffic: Bool
    @State private var notiAuthorized = false

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
        _quotaThreshold = State(initialValue: s.quotaWarningThreshold)
        _showAppTraffic = State(initialValue: UserDefaults.standard.object(forKey: "popover_show_app_traffic") as? Bool ?? true)
    }

    private let menuBarOptions: [(String, Double)] = [("1초", 1), ("2초", 2), ("3초", 3)]
    private let cacheOptions: [(String, Double)] = [("5초", 5), ("10초", 10), ("20초", 20), ("30초", 30)]
    private let trafficOptions: [(String, Double)] = [("3초", 3), ("5초", 5), ("10초", 10), ("15초", 15)]
    private let pingOptions: [(String, Double)] = [("3초", 3), ("5초", 5), ("10초", 10)]
    private let thresholdOptions: [(String, Double)] = [("사용 안 함", 1.0), ("50%", 0.5), ("80%", 0.8), ("90%", 0.9), ("95%", 0.95)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("설정")
                .font(.headline)
                .padding(.top, 20)
                .frame(maxWidth: .infinity)

            Group {
                Toggle("메뉴바에 총 사용량 표시", isOn: $showTotalColumn)
                    .onChange(of: showTotalColumn) { _, newValue in
                        SettingsManager.shared.showTotalColumn = newValue
                        NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                    }

                Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
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
                    Text("메뉴바")
                        .font(.subheadline).bold()
                    HStack {
                        Text("폰트 크기")
                            .font(.caption)
                        Text("(기본: \(Int(SettingsManager.defaultMenuBarFontSize))pt)")
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
                        Text("앱별 트래픽 표시")
                            .font(.caption)
                        Spacer()
                        Picker("", selection: $showAppTraffic) {
                            Text("표시").tag(true)
                            Text("숨김").tag(false)
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
                    HStack {
                        Text("알림")
                            .font(.subheadline).bold()
                        Spacer()
                        if notiAuthorized {
                            Text("✅ 허용됨")
                                .font(.caption)
                                .foregroundColor(.green)
                                .frame(width: 110, alignment: .trailing)
                        } else {
                            Button("알림 허용") {
                                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                                    DispatchQueue.main.async { notiAuthorized = granted }
                                }
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?com.tetherlens.app") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .frame(width: 110, alignment: .trailing)
                        }
                    }
                    HStack {
                        Text("할당량 알림")
                            .font(.caption)
                        Text("(기본: 사용 안 함)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $quotaThreshold) {
                            ForEach(thresholdOptions, id: \.1) { opt in
                                Text(opt.0).tag(opt.1)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                        .onChange(of: quotaThreshold) { _, newValue in
                            SettingsManager.shared.quotaWarningThreshold = newValue
                        }
                    }
                    .padding(.leading, 12)
                    Divider()
                    HStack {
                        Text("지연 시간 알림")
                            .font(.caption)
                        Text("(기본: 표시)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { SettingsManager.shared.pingLatencyNotificationEnabled },
                            set: { SettingsManager.shared.pingLatencyNotificationEnabled = $0 }
                        )) {
                            Text("표시").tag(true)
                            Text("숨김").tag(false)
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
                Text("성능")
                    .font(.subheadline).bold()
                Spacer()
                Button("기본값 복원") {
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
                pollingRow(label: "메뉴바 갱신 주기", defaultValue: SettingsManager.defaultMenuBarRefreshInterval, selection: $menuBarInterval, options: menuBarOptions)
                pollingRow(label: "데이터 캐시 갱신", defaultValue: SettingsManager.defaultCacheRefreshInterval, selection: $cacheInterval, options: cacheOptions)
                pollingRow(label: "앱 트래픽 갱신", defaultValue: SettingsManager.defaultTrafficMonitorInterval, selection: $trafficInterval, options: trafficOptions)
                pollingRow(label: "Ping 측정 주기", defaultValue: SettingsManager.defaultPingInterval, selection: $pingInterval, options: pingOptions)
            }
            .padding(.leading, 32)
            .padding(.trailing, 20)

            Spacer()

            HStack {
                Spacer()
                Button("닫기", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 320, height: 540)
        .onAppear {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let authorized = settings.authorizationStatus == .authorized
                DispatchQueue.main.async { notiAuthorized = authorized }
            }
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
            Text("(기본: \(formatInterval(defaultValue)))")
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
        "\(Int(interval))초"
    }
}
