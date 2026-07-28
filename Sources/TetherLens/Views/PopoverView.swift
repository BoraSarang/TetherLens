import SwiftUI

struct PopoverView: View {
    let networkMonitor: NetworkMonitor
    let hotspotDetector: HotspotDetector
    let pingMonitor: PingMonitor
    let ipResolver: IPResolver
    let locationManager: LocationManager
    let onTogglePin: (() -> Void)?
    @State private var pinned = false

    private struct PingAlert {
        let message: String
        let type: AppNotification.NotificationType
    }

    private struct UsageReportConfig: Identifiable {
        let id = UUID()
        let preselectedProfileId: UUID?
    }

    @State private var tick = Date()
    @State private var showDNSPicker = false
    @State private var dnsStatusMessage: String?
    @State private var confirmPreset: DNSPreset?
    @State private var currentDNSServers: [String] = []
    @State private var applyingPresetID: UUID?
    @State private var profiles: [Profile] = []
    @State private var showProfileManager = false
    @State private var editingProfile: Profile?
    @State private var showSettings = false
    @State private var showSavingMode = false
    @State private var savingModeActive = SavingModeManager.shared.isEnabled
    @State private var usageReportConfig: UsageReportConfig?
    @State private var showTraffic = false
    @State private var showAbout = false
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @State private var sessionStartTime: Date?
    @State private var quotaAlertMessage: String?
    @State private var pingAlert: PingAlert?
    @State private var showNotifications = false
    @State private var copiedIPMessage: String?
    @AppStorage("popover_expanded_connection_info") private var expandedConnectionInfo = false
    @AppStorage("popover_expanded_address_info") private var expandedAddressInfo = false
    @AppStorage("popover_show_app_traffic") private var showAppTraffic = true

    var body: some View {
        mainContent
            .sheet(isPresented: $showDNSPicker) {
                dnsPresetPicker
                    .onAppear {
                        currentDNSServers = DNSManager.shared.currentServers()
                        applyingPresetID = nil
                        dnsStatusMessage = nil
                    }
            }
            .sheet(isPresented: $showProfileManager) {
                profileManagerSheet
                    .onAppear { profiles = ProfileManager.shared.getAllProfiles() }
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditorView(
                    profile: profile,
                    currentSSID: ssidString,
                    onClose: { editingProfile = nil },
                    onProfilesChanged: { profiles = ProfileManager.shared.getAllProfiles() }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(onClose: { showSettings = false })
            }
            .sheet(isPresented: $showSavingMode) {
                SavingModeSheet(onClose: { showSavingMode = false })
            }
            .sheet(item: $usageReportConfig) { config in
                UsageReportView(onClose: { usageReportConfig = nil }, preselectedProfileId: config.preselectedProfileId)
            }
            .sheet(isPresented: $showTraffic) {
                AppTrafficView(onClose: { showTraffic = false })
            }
            .sheet(isPresented: $showAbout) {
                AboutView(onClose: { showAbout = false })
            }
            .sheet(isPresented: $showNotifications) {
                NotificationListView(onClose: { showNotifications = false })
            }
        .onReceive(NotificationCenter.default.publisher(for: .init("settingsChanged"))) { _ in
            tick = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("quotaAlert"))) { notification in
            if let msg = notification.userInfo?["message"] as? String {
                quotaAlertMessage = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.quotaAlertMessage = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("pingAlert"))) { notification in
            if let msg = notification.userInfo?["message"] as? String {
                let typeRaw = notification.userInfo?["type"] as? String ?? ""
                let type = AppNotification.NotificationType(rawValue: typeRaw) ?? .pingWarning
                pingAlert = PingAlert(message: msg, type: type)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.pingAlert = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("savingModeChanged"))) { _ in
                savingModeActive = SavingModeManager.shared.isEnabled
                tick = Date()
            }
    }

    private var mainContent: some View {
        VStack(spacing: 12) {
            headerView
            collapsibleSectionDivider("연결 정보", isExpanded: $expandedConnectionInfo)
            connectionInfoView
            collapsibleSectionDivider("연결 주소", isExpanded: $expandedAddressInfo)
            connectionAddressView
            sectionDivider("QoS 방지 게이지")
            qosGaugeBody
            if let msg = quotaAlertMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        quotaAlertMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange)
                .cornerRadius(6)
            }
            if let alert = pingAlert {
                HStack(spacing: 6) {
                    Image(systemName: pingAlertIcon(for: alert.type))
                        .font(.caption)
                        .foregroundColor(.white)
                    Text(alert.message)
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        pingAlert = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(pingAlertColor(for: alert.type))
                .cornerRadius(6)
            }
            if let msg = copiedIPMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green)
                .cornerRadius(6)
                .transition(.opacity)
            }
            if showAppTraffic, !trafficMonitor.apps.isEmpty {
                trafficSectionDivider
                appTrafficPreview
            }
            sectionDivider("프로필")
            profileSection
            Divider()
            speedView
            Divider()
            bottomButtons
        }
        .padding(16)
        .frame(width: 280)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tick = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("connectionChanged"))) { _ in
            hotspotDetector.refreshNow()
            tick = Date()
            profiles = ProfileManager.shared.getAllProfiles()
            updateSessionStartTime()
        }
        .onAppear {
            updateSessionStartTime()
        }
    }

    private var headerView: some View {
        HStack {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 20, height: 20)
            Text(connectionName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let onTogglePin {
                Button {
                    pinned.toggle()
                    onTogglePin()
                } label: {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(pinned ? .accentColor : .secondary)
                .help(pinned ? "고정 해제" : "팝오버 고정")
            }
            Button {
                showNotifications = true
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "bell")
                        .font(.caption)
                    if !NotificationManager.shared.notifications.isEmpty {
                        Text("\(NotificationManager.shared.notifications.count)")
                            .font(.system(size: 8, design: .monospaced))
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(NotificationManager.shared.notifications.isEmpty ? .secondary : .accentColor)
            .help("알림 기록")
            statusDot
        }
    }

    private var connectionIcon: String {
        guard let conn = hotspotDetector.currentConnection else { return "wifi" }
        switch conn.type {
        case .iOSPersonalHotspot, .androidHotspot:
            return "personalhotspot"
        case .ethernet:
            return "cable.connector"
        case .normalWiFi:
            return "wifi"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var connectionName: String {
        guard let conn = hotspotDetector.currentConnection else { return "연결 없음" }
        switch conn.type {
        case .iOSPersonalHotspot(let ssid):
            return ssid ?? "iOS 핫스팟"
        case .androidHotspot(let ssid):
            return ssid ?? "Android 핫스팟"
        case .normalWiFi(let ssid, _):
            return ssid ?? "Wi-Fi"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "알 수 없음"
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(pingMonitor.isReachable ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }

    private var ssidString: String? {
        guard let conn = hotspotDetector.currentConnection else { return nil }
        switch conn.type {
        case .normalWiFi(let ssid, _): return ssid
        case .iOSPersonalHotspot(let ssid): return ssid
        case .androidHotspot(let ssid): return ssid
        default: return nil
        }
    }

    private var bssidString: String? {
        guard let conn = hotspotDetector.currentConnection else { return nil }
        switch conn.type {
        case .normalWiFi(_, let bssid): return bssid
        default: return nil
        }
    }

    private var usesWiFi: Bool {
        guard let conn = hotspotDetector.currentConnection else { return false }
        switch conn.type {
        case .normalWiFi, .iOSPersonalHotspot, .androidHotspot: return true
        default: return false
        }
    }

    private var connectionInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(label: "유형", value: connectionTypeString)
            if let dur = sessionDurationString {
                detailRow(label: "세션", value: dur)
            }
            if let ssid = ssidString {
                let rssiSuffix: String = {
                    guard let r = hotspotDetector.currentConnection?.rssi else { return "" }
                    return " (\(r)dBm)"
                }()
                detailRow(label: "네트워크", value: "\(ssid)\(rssiSuffix)", copyValue: ssid)
            } else if usesWiFi {
                let rssiSuffix: String = {
                    guard let r = hotspotDetector.currentConnection?.rssi else { return "" }
                    return " (\(r)dBm)"
                }()
                detailRow(label: "네트워크", value: "알 수 없음\(rssiSuffix)")
            }
            if let bssid = bssidString {
                detailRow(label: "BSSID", value: bssid, copyValue: bssid)
            }
            if expandedConnectionInfo {
                if let phy = hotspotDetector.currentConnection?.phyMode {
                    detailRow(label: "규격", value: phy)
                }
                if let ch = hotspotDetector.currentConnection?.channel,
                   let band = hotspotDetector.currentConnection?.channelBand {
                    let width = hotspotDetector.currentConnection?.channelWidth ?? 0
                    detailRow(label: "채널", value: width > 0 ? "\(ch) (\(band), \(width)MHz)" : "\(ch) (\(band))")
                }
                if let speed = hotspotDetector.currentConnection?.linkSpeed {
                    detailRow(label: "속도", value: String(format: "%.0f Mbps", speed))
                }
            }
        }
    }

    private var connectionAddressView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if expandedAddressInfo {
                if let gw = hotspotDetector.currentConnection?.gatewayIP {
                    detailRow(label: "게이트웨이", value: gw, copyValue: gw)
                }
            }
            if let ip = hotspotDetector.currentConnection?.localIP {
                detailRow(label: "로컬 IP", value: ip, copyValue: ip)
            }
            if let extIP = ipResolver.externalIP {
                let country = ipResolver.geoInfo?.countryCode.map { " (\(flag(from: $0)))" } ?? ""
                detailRow(label: "외부 IP", value: "\(extIP)\(country)", copyValue: extIP)
            }
            if expandedAddressInfo {
                if let dns = hotspotDetector.currentConnection?.dnsServers, !dns.isEmpty {
                    detailRow(label: "DNS", value: dns.joined(separator: ", "))
                        .onTapGesture { showDNSPicker = true }
                }
            }
            detailRow(label: "지연 시간 (Ping)", value: pingString)
            if usesWiFi && ssidString == nil {
                locationWarningView
            }
        }
    }

    private var connectionTypeString: String {
        guard let conn = hotspotDetector.currentConnection else { return "-" }
        switch conn.type {
        case .iOSPersonalHotspot:
            return "iOS 핫스팟"
        case .androidHotspot:
            return "Android 핫스팟"
        case .normalWiFi:
            return "Wi-Fi"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "알 수 없음"
        }
    }

    private var pingString: String {
        if let dns = pingMonitor.dnsRTT {
            let ms = Int(dns * 1000)
            return "\(ms)ms (8.8.8.8)"
        }
        return "측정 중..."
    }

    private var sessionDurationString: String? {
        guard let startTime = sessionStartTime else { return nil }
        let _ = tick
        let interval = Date().timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var locationWarningView: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "location.slash")
                .font(.caption2)
                .foregroundColor(.orange)
                .padding(.top, 2)
            if !LocationManager.systemLocationServicesEnabled {
                Text("시스템 설정 > 개인정보 보호 및 보안 >\n위치 서비스를 켜주세요")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                Text("시스템 설정 > 개인정보 보호 및 보안 >\n위치 서비스 > TetherLens를 허용해주세요")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else if !locationManager.isAuthorized {
                Text("TetherLens가 Wi-Fi 정보를 읽기 위해\n위치 접근 권한이 필요합니다")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("권한 요청") {
                    locationManager.requestAuthorization()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else {
                Text("Wi-Fi 정보(SSID)를 읽을 수 없습니다.\nApple Developer 프로비저닝이 필요합니다")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button("설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var qosGaugeBody: some View {
        let ssid = hotspotDetector.currentConnection?.ssid
        let profile = ssid.flatMap { ProfileManager.shared.getProfile(ssid: $0) }
        let todayUsage = profile.map { ProfileManager.shared.getTodayUsage(profileId: $0.id) } ?? (0, 0)
        let totalUsedGB = Double(todayUsage.upload + todayUsage.download) / 1_000_000_000
        let quotaGB = profile?.quotaGB
        if let quotaGB = quotaGB {
            QoSGauge(used: totalUsedGB, total: quotaGB, saving: SavingModeManager.shared.isEnabled)
        } else {
            HStack {
                Spacer()
                Text("할당량 없음 — 프로필 편집에서 설정하세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private var trafficSectionDivider: some View {
        HStack(spacing: 6) {
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
            Text("프로세스별 트래픽")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize()
            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(.secondary.opacity(0.5))
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
        }
        .contentShape(Rectangle())
        .onTapGesture { showTraffic = true }
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private var appTrafficPreview: some View {
        let top3 = Array(trafficMonitor.apps.prefix(3))
        return VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("프로세스")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("▲ 업로드")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .frame(width: 62, alignment: .trailing)
                Text("▼ 다운로드")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 68, alignment: .trailing)
            }
            ForEach(top3) { app in
                HStack(spacing: 0) {
                    Text(app.processName)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatByteRate(app.bytesIn))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange)
                        .frame(width: 62, alignment: .trailing)
                    Text(formatByteRate(app.bytesOut))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.blue)
                        .frame(width: 68, alignment: .trailing)
                }
            }
            Button("더보기...") { showTraffic = true }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture { showTraffic = true }
    }

    private var profileSection: some View {
        let currentSSID = hotspotDetector.currentConnection?.ssid
        let currentProfile = currentSSID.flatMap { ProfileManager.shared.getProfile(ssid: $0) }
        return VStack(spacing: 6) {
            if let profile = currentProfile {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name).font(.body)
                        Text(profile.ssid).font(.caption).foregroundColor(.secondary)
                        if let q = profile.quotaGB {
                            Text("할당량 \(String(format: "%.1f", q))GB").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button("통계") {
                        usageReportConfig = UsageReportConfig(preselectedProfileId: profile.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("편집") {
                        editingProfile = profile
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            Button("프로필 관리...") { showProfileManager = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
        }
    }

    private var profileManagerSheet: some View {
        VStack(spacing: 12) {
            Text("프로필 관리")
                .font(.headline)
                .padding(.top, 16)

            if profiles.isEmpty {
                Spacer()
                Text("등록된 프로필이 없습니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(profiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(profile.name).font(.body)
                                    if profile.ssid == ssidString {
                                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                                        Text("접속 중").font(.caption2).foregroundColor(.orange)
                                    }
                                }
                                Text(profile.ssid).font(.caption).foregroundColor(.secondary)
                                if let q = profile.quotaGB {
                                    Text("할당량 \(String(format: "%.1f", q))GB").font(.caption2)
                                }
                                if profile.ssid != ssidString {
                                    Text("마지막 접속: \(relativeTimeString(profile.lastConnected))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("통계") {
                                showProfileManager = false
                                usageReportConfig = UsageReportConfig(preselectedProfileId: profile.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("편집") {
                                showProfileManager = false
                                editingProfile = profile
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            ProfileManager.shared.deleteProfile(id: profiles[i].id)
                        }
                        profiles = ProfileManager.shared.getAllProfiles()
                    }
                }
                .listStyle(.plain)
            }

            Button("닫기") { showProfileManager = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, 16)
        }
        .frame(width: 280, height: 300)
    }

    private var speedView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("▲ 업로드")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatSpeed(networkMonitor.currentUploadSpeed))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.orange)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("▼ 다운로드")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatSpeed(networkMonitor.currentDownloadSpeed))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Menu {
                Button("사용량 리포트") { openStatistics() }
                Button("프로세스별 트래픽") { showTraffic = true }
                Button("알림 기록") { showNotifications = true }
                Divider()
                Button("DNS 프리셋 적용") { showDNSPicker = true }
                Button(savingModeActive ? "절약 모드 온" : "절약 모드") { openSavingMode() }
                Divider()
                Button("설정") { showSettings = true }
                Button("업데이트 확인") { UpdaterManager.shared.checkForUpdates() }
                Button("정보") { showAbout = true }
                #if DEBUG
                Divider()
                Button("🐛 디버그 패널") { DebugPanelController.shared.toggle() }
                #endif
            } label: {
                Text("더보기")
                    .font(.caption)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
            Button("☕️ 후원") { openDonation() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("종료") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
        }
    }

    private func detailRow(label: String, value: String, copyValue: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 96, alignment: .leading)
            HStack(spacing: 3) {
                if copyValue != nil {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let copyValue else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyValue, forType: .string)
            copiedIPMessage = "\(copyValue)가 복사되었습니다."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copiedIPMessage = nil
            }
        }
    }

    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
            Text(title).font(.caption2).foregroundColor(.secondary).fixedSize()
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
        }
    }

    private func collapsibleSectionDivider(_ title: String, isExpanded: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
            Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            Text(title).font(.caption2).foregroundColor(.secondary).fixedSize()
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
        }
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.wrappedValue.toggle() }
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private var dnsPresetPicker: some View {
        VStack(spacing: 12) {
            Text("DNS 프리셋 선택")
                .font(.headline)
                .padding(.top, 16)

            ForEach(DNSPreset.presets) { preset in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name).font(.body)
                        Text(preset.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(preset.servers.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                    Group {
                        if applyingPresetID == preset.id {
                            Text("적용 중...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if !preset.servers.isEmpty && currentDNSServers == preset.servers {
                            Text("적용됨")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        } else {
                            Button("적용") { confirmPreset = preset }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .frame(minWidth: 48, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                Divider()
            }

            if let msg = dnsStatusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("닫기") { showDNSPicker = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, 16)
        }
        .frame(width: 260)
        .alert(item: $confirmPreset) { preset in
            Alert(
                title: Text("DNS 변경"),
                message: Text("""
\(preset.name) (\(preset.servers.joined(separator: ", ")))(으)로 변경하시겠습니까?

변경을 위해 관리자 비밀번호가 필요합니다.
"""),
                primaryButton: .cancel(Text("취소")),
                secondaryButton: .default(Text("적용")) {
                    applyDNSPreset(preset)
                }
            )
        }
    }

    private func applyDNSPreset(_ preset: DNSPreset) {
        applyingPresetID = preset.id
        dnsStatusMessage = "적용 중..."
        DNSManager.shared.applyPreset(preset) { success, message in
            DispatchQueue.main.async {
                applyingPresetID = nil
                if success {
                    dnsStatusMessage = "✓ \(message) DNS 적용 완료"
                    currentDNSServers = preset.servers
                } else {
                    dnsStatusMessage = "✗ \(message)"
                }
            }
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        let Bps = bps / 8
        if Bps >= 1_000_000_000 {
            return String(format: "%.1f GB/s", Bps / 1_000_000_000)
        } else if Bps >= 1_000_000 {
            return String(format: "%.1f MB/s", Bps / 1_000_000)
        } else if Bps >= 1_000 {
            return String(format: "%.1f KB/s", Bps / 1_000)
        } else {
            return String(format: "%.0f B/s", Bps)
        }
    }

    private func formatByteRate(_ bytesPerSecond: Int64) -> String {
        let bps = Double(bytesPerSecond)
        if bps >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bps / 1_000_000_000)
        } else if bps >= 1_000_000 {
            return String(format: "%.1f MB/s", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.1f KB/s", bps / 1_000)
        } else {
            return String(format: "%.0f B/s", bps)
        }
    }

    private func pingAlertIcon(for type: AppNotification.NotificationType) -> String {
        switch type {
        case .pingWarning, .connectionLost: return "exclamationmark.triangle.fill"
        case .pingCritical: return "xmark.circle.fill"
        case .pingRecovery, .connectionRestored: return "checkmark.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private func pingAlertColor(for type: AppNotification.NotificationType) -> Color {
        switch type {
        case .pingWarning: return .orange
        case .pingCritical: return .red
        case .pingRecovery, .connectionRestored: return .green
        case .connectionLost: return .blue
        default: return .orange
        }
    }

    private func relativeTimeString(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "방금 전" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        if interval < 604800 { return "\(Int(interval / 86400))일 전" }
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: date)
    }

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func openStatistics() {
        usageReportConfig = UsageReportConfig(preselectedProfileId: nil)
    }

    private func openSavingMode() {
        showSavingMode = true
    }

    private func openDonation() {
        let url = URL(string: "https://buymeacoffee.com/okstart")!
        NSWorkspace.shared.open(url)
    }

    private func flag(from countryCode: String) -> String {
        let base: UInt32 = 127_397
        return countryCode
            .unicodeScalars
            .map { String(UnicodeScalar(base + $0.value)!) }
            .joined()
    }

    private func updateSessionStartTime() {
        guard let ssid = ssidString,
              let profile = ProfileManager.shared.getProfile(ssid: ssid),
              let session = ProfileManager.shared.getActiveSession(profileId: profile.id)
        else {
            sessionStartTime = nil
            return
        }
        sessionStartTime = session.startTime
    }
}
