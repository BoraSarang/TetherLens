import SwiftUI

struct PopoverView: View {
    let networkMonitor: NetworkMonitor
    let hotspotDetector: HotspotDetector
    let pingMonitor: PingMonitor
    let ipResolver: IPResolver
    let locationManager: LocationManager

    @State private var refreshID = UUID()
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
    @State private var showUsageReport = false

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
            .sheet(isPresented: $showUsageReport) {
                UsageReportView(onClose: { showUsageReport = false })
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("settingsChanged"))) { _ in
                refreshID = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("savingModeChanged"))) { _ in
                savingModeActive = SavingModeManager.shared.isEnabled
                refreshID = UUID()
            }
    }

    private var mainContent: some View {
        VStack(spacing: 12) {
            headerView
            sectionDivider("연결 정보")
            connectionInfoView
            sectionDivider("연결 주소")
            connectionAddressView
            sectionDivider("QoS 방지 게이지")
            qosGaugeBody
            sectionDivider("프로필")
            profileSection
            Divider()
            speedView
            Divider()
            bottomButtons
        }
        .id(refreshID)
        .padding(16)
        .frame(width: 280)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("connectionChanged"))) { _ in
            hotspotDetector.refreshNow()
            refreshID = UUID()
            profiles = ProfileManager.shared.getAllProfiles()
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: connectionIcon)
                .font(.title2)
            Text(connectionName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
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
                detailRow(label: "네트워크", value: "\(ssid)\(rssiSuffix)")
            } else if usesWiFi {
                let rssiSuffix: String = {
                    guard let r = hotspotDetector.currentConnection?.rssi else { return "" }
                    return " (\(r)dBm)"
                }()
                detailRow(label: "네트워크", value: "알 수 없음\(rssiSuffix)")
            }
            if let bssid = bssidString {
                detailRow(label: "BSSID", value: bssid)
            }
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

    private var connectionAddressView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let gw = hotspotDetector.currentConnection?.gatewayIP {
                detailRow(label: "게이트웨이", value: gw)
            }
            if let ip = hotspotDetector.currentConnection?.localIP {
                detailRow(label: "로컬 IP", value: ip)
            }
            if let extIP = ipResolver.externalIP {
                let country = ipResolver.geoInfo?.countryCode.map { " (\(flag(from: $0)))" } ?? ""
                detailRow(label: "외부 IP", value: "\(extIP)\(country)")
            }
            if let dns = hotspotDetector.currentConnection?.dnsServers, !dns.isEmpty {
                detailRow(label: "DNS", value: dns.joined(separator: ", "))
                    .onTapGesture { showDNSPicker = true }
            }
            detailRow(label: "Ping", value: pingString)
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
        guard let ssid = ssidString,
              let profile = ProfileManager.shared.getProfile(ssid: ssid),
              let session = ProfileManager.shared.getActiveSession(profileId: profile.id)
        else { return nil }
        let interval = Date().timeIntervalSince(session.startTime)
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
                            }
                            Spacer()
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
                Button("통계") { openStatistics() }
                Button("DNS 프리셋 적용") { showDNSPicker = true }
                Button(savingModeActive ? "절약 모드 온" : "절약 모드") { openSavingMode() }
                Button("설정") { showSettings = true }
            } label: {
                Text("더보기")
                    .font(.caption)
            }
            .menuIndicator(.hidden)
            .tint(savingModeActive ? .orange : .secondary)
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

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
            Text(title).font(.caption2).foregroundColor(.secondary).fixedSize()
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
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

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func openStatistics() {
        showUsageReport = true
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
}
