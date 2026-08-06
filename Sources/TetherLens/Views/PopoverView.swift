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
    @State private var showIPHistory = false
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @State private var sessionStartTime: Date?
    @State private var quotaAlertMessage: String?
    @State private var pingAlert: PingAlert?
    @State private var showNotifications = false
    @State private var copiedIPMessage: String?
    @AppStorage("popover_expanded_connection_info") private var expandedConnectionInfo = false
    @AppStorage("popover_expanded_address_info") private var expandedAddressInfo = false
    @AppStorage("popover_show_app_traffic") private var showAppTraffic = true
    @AppStorage("popover_summary_mode") private var summaryMode = true

    // publisher 정체성 고정 (body 재평가마다 새 Timer가 만들어지는 것을 방지)
    private static let tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
            .sheet(isPresented: $showIPHistory) {
                if let pid = currentProfileId {
                    IPHistoryView(profileId: pid, onClose: { showIPHistory = false })
                }
            }
        .onReceive(NotificationCenter.default.publisher(for: .init("settingsChanged"))) { _ in
            tick = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("quotaAlert"))) { notification in
            if let msg = notification.userInfo?["message"] as? String {
                let expected = msg
                quotaAlertMessage = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    // 5초 내 새 알림이 온 경우 이전 클리어가 새 알림을 지우지 않도록 현재 값 비교
                    if self.quotaAlertMessage == expected {
                        self.quotaAlertMessage = nil
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("pingAlert"))) { notification in
            if let msg = notification.userInfo?["message"] as? String {
                let typeRaw = notification.userInfo?["type"] as? String ?? ""
                let type = AppNotification.NotificationType(rawValue: typeRaw) ?? .pingWarning
                let expected = PingAlert(message: msg, type: type)
                pingAlert = expected
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    if self.pingAlert?.message == expected.message {
                        self.pingAlert = nil
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("savingModeChanged"))) { _ in
                savingModeActive = SavingModeManager.shared.isEnabled
                tick = Date()
            }
        .onReceive(NotificationCenter.default.publisher(for: .init("moreAction"))) { notification in
            guard let action = notification.userInfo?["action"] as? String else { return }
            switch action {
            case "usageReport": openStatistics()
            case "appTraffic": showTraffic = true
            case "notifications": showNotifications = true
            case "dnsPreset": showDNSPicker = true
            case "savingMode": openSavingMode()
            case "settings": showSettings = true
            case "about": showAbout = true
            default: break
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: TLSpace.xl) {
            headerView
            bannerStack
            speedView
            qosGaugeBody
            if !summaryMode {
                detailSections
            }
            Divider()
            bottomButtons
        }
        .padding(TLSpace.inset)
        .frame(width: TLSize.popoverWidth)
        .onReceive(Self.tickTimer) { _ in
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

    @ViewBuilder
    private var bannerStack: some View {
        if let msg = quotaAlertMessage {
            quotaBanner(msg)
        }
        if let alert = pingAlert {
            pingBanner(alert)
        }
        if let msg = copiedIPMessage {
            copiedBanner(msg)
        }
    }

    private func quotaBanner(_ msg: String) -> some View {
        HStack(spacing: TLSpace.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TLFont.caption)
                .foregroundColor(.white)
            Text(msg)
                .font(TLFont.caption)
                .foregroundColor(.white)
            Spacer()
            Button {
                quotaAlertMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(TLFont.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, TLSpace.lg)
        .padding(.vertical, TLSpace.sm)
        .background(TLPalette.upload)
        .cornerRadius(TLRound.small)
    }

    private func pingBanner(_ alert: PingAlert) -> some View {
        HStack(spacing: TLSpace.sm) {
            Image(systemName: pingAlertIcon(for: alert.type))
                .font(TLFont.caption)
                .foregroundColor(.white)
            Text(alert.message)
                .font(TLFont.caption)
                .foregroundColor(.white)
            Spacer()
            Button {
                pingAlert = nil
            } label: {
                Image(systemName: "xmark")
                    .font(TLFont.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, TLSpace.lg)
        .padding(.vertical, TLSpace.sm)
        .background(pingAlertColor(for: alert.type))
        .cornerRadius(TLRound.small)
    }

    private func copiedBanner(_ msg: String) -> some View {
        HStack(spacing: TLSpace.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(TLFont.caption)
                .foregroundColor(.white)
            Text(msg)
                .font(TLFont.caption)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, TLSpace.lg)
        .padding(.vertical, TLSpace.sm)
        .background(TLPalette.success)
        .cornerRadius(TLRound.small)
        .transition(.opacity)
    }

    @ViewBuilder
    private var detailSections: some View {
        collapsibleSectionDivider(Localized.connectionInfo, isExpanded: $expandedConnectionInfo)
        connectionInfoView
        collapsibleSectionDivider(Localized.addressInfo, isExpanded: $expandedAddressInfo)
        connectionAddressView
        if showAppTraffic, !trafficMonitor.apps.isEmpty {
            trafficSectionDivider
            appTrafficPreview
        }
        sectionDivider(Localized.profile)
        profileSection
    }

    private var headerView: some View {
        HStack {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 20, height: 20)
            Text(displayName)
                .font(TLFont.headline)
                .lineLimit(1)
            Spacer()
            if let onTogglePin {
                Button {
                    pinned.toggle()
                    onTogglePin()
                } label: {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .font(TLFont.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(pinned ? TLPalette.accent : TLPalette.textSecondary)
                .help(pinned ? Localized.unpin : Localized.pinPopover)
            }
            Button {
                showNotifications = true
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "bell")
                        .font(TLFont.caption)
                    if !NotificationManager.shared.notifications.isEmpty {
                        Text("\(NotificationManager.shared.notifications.count)")
                            .font(TLFont.badgeMono)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(NotificationManager.shared.notifications.isEmpty ? TLPalette.textSecondary : TLPalette.accent)
            .help(Localized.notificationHistory)
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
        guard let conn = hotspotDetector.currentConnection else { return Localized.noConnection }
        switch conn.type {
        case .iOSPersonalHotspot(let ssid):
            return ssid ?? Localized.iOSHotspot
        case .androidHotspot(let ssid):
            return ssid ?? Localized.androidHotspot
        case .normalWiFi(let ssid, _):
            return ssid ?? Localized.wifi
        case .ethernet:
            return Localized.ethernet
        case .unknown:
            return Localized.unknown
        }
    }

    private var displayName: String {
        guard let ssid = ssidString else { return connectionName }
        if let profile = ProfileManager.shared.getProfile(ssid: ssid) {
            return profile.name
        }
        return connectionName
    }

    private var statusDot: some View {
        Circle()
            .fill(pingMonitor.isReachable ? TLPalette.success : TLPalette.danger)
            .frame(width: 10, height: 10)
    }

    private var currentProfileId: UUID? {
        guard let ssid = ssidString else { return nil }
        return ProfileManager.shared.getProfile(ssid: ssid)?.id
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
        VStack(alignment: .leading, spacing: TLSpace.sm) {
            detailRow(label: Localized.type, value: connectionTypeString)
            if let dur = sessionDurationString {
                detailRow(label: Localized.session, value: dur)
            }
            if let ssid = ssidString {
                let rssiSuffix: String = {
                    guard let r = hotspotDetector.currentConnection?.rssi else { return "" }
                    return " (\(r)dBm)"
                }()
                detailRow(label: Localized.network, value: "\(ssid)\(rssiSuffix)", copyValue: ssid)
            } else if usesWiFi {
                let rssiSuffix: String = {
                    guard let r = hotspotDetector.currentConnection?.rssi else { return "" }
                    return " (\(r)dBm)"
                }()
                detailRow(label: Localized.network, value: "\(Localized.unknown)\(rssiSuffix)")
            }
            if let bssid = bssidString {
                detailRow(label: Localized.bssid, value: bssid, copyValue: bssid)
            }
            if expandedConnectionInfo {
                if let phy = hotspotDetector.currentConnection?.phyMode {
                    detailRow(label: Localized.standard, value: phy)
                }
                if let ch = hotspotDetector.currentConnection?.channel,
                   let band = hotspotDetector.currentConnection?.channelBand {
                    let width = hotspotDetector.currentConnection?.channelWidth ?? 0
                    detailRow(label: Localized.channel, value: width > 0 ? "\(ch) (\(band), \(width)MHz)" : "\(ch) (\(band))")
                }
                if let speed = hotspotDetector.currentConnection?.linkSpeed {
                    detailRow(label: Localized.speed, value: String(format: "%.0f Mbps", speed))
                }
            }
        }
    }

    private var connectionAddressView: some View {
        VStack(alignment: .leading, spacing: TLSpace.sm) {
            if expandedAddressInfo {
                if let gw = hotspotDetector.currentConnection?.gatewayIP {
                    detailRow(label: Localized.gateway, value: gw, copyValue: gw)
                }
            }
            if let ip = hotspotDetector.currentConnection?.localIP {
                detailRow(label: Localized.localIP, value: ip, copyValue: ip)
            }
            if let extIP = ipResolver.externalIP {
                let country = ipResolver.geoInfo.map { " (\(flag(from: $0.countryCode)))" } ?? ""
                detailRow(label: Localized.externalIP, value: "\(extIP)\(country)", copyValue: extIP)
            }
            if currentProfileId != nil {
                HStack {
                    Spacer()
                    Button(Localized.ipHistory) { showIPHistory = true }
                        .buttonStyle(.plain)
                        .font(TLFont.small)
                        .foregroundColor(TLPalette.accent)
                }
            }
            if expandedAddressInfo {
                if let dns = hotspotDetector.currentConnection?.dnsServers, !dns.isEmpty {
                    HStack(spacing: TLSpace.xs) {
                        detailRow(label: Localized.dns, value: dns.joined(separator: ", "))
                        Image(systemName: "chevron.right")
                            .font(TLFont.badge)
                            .foregroundColor(TLPalette.textSecondary.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showDNSPicker = true }
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() }
                        else { NSCursor.pop() }
                    }
                }
            }
            detailRow(label: Localized.ping, value: pingString)
            if usesWiFi && ssidString == nil {
                locationWarningView
            }
        }
    }

    private var connectionTypeString: String {
        guard let conn = hotspotDetector.currentConnection else { return "-" }
        switch conn.type {
        case .iOSPersonalHotspot:
            return Localized.iOSHotspot
        case .androidHotspot:
            return Localized.androidHotspot
        case .normalWiFi:
            return Localized.wifi
        case .ethernet:
            return Localized.ethernet
        case .unknown:
            return Localized.unknown
        }
    }

    private var pingString: String {
        if let dns = pingMonitor.dnsRTT {
            let ms = Int(dns * 1000)
            return "\(ms)ms (8.8.8.8)"
        }
        return Localized.measuring
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
        HStack(alignment: .top, spacing: TLSpace.xs) {
            Image(systemName: "location.slash")
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.upload)
                .padding(.top, 2)
            if !LocationManager.systemLocationServicesEnabled {
                Text(Localized.locationServiceOff)
                    .font(TLFont.small)
                    .foregroundColor(TLPalette.upload)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TLSpace.xs)
                Button(Localized.openSettings) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(TLPalette.upload)
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                Text(Localized.locationAppDenied)
                    .font(TLFont.small)
                    .foregroundColor(TLPalette.upload)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TLSpace.xs)
                Button(Localized.openSettings) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(TLPalette.upload)
            } else if !locationManager.isAuthorized {
                Text(Localized.locationNeeded)
                    .font(TLFont.small)
                    .foregroundColor(TLPalette.upload)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TLSpace.xs)
                Button(Localized.requestPermission) {
                    locationManager.requestAuthorization()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(TLPalette.upload)
            } else {
                Text(Localized.locationProvisioning)
                    .font(TLFont.small)
                    .foregroundColor(TLPalette.upload)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TLSpace.xs)
                Button(Localized.openSettings) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(TLPalette.upload)
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
            QoSGauge(used: totalUsedGB, total: quotaGB)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let profile = profile {
                        usageReportConfig = UsageReportConfig(preselectedProfileId: profile.id)
                    }
                }
        } else {
            HStack(spacing: TLSpace.sm) {
                Spacer()
                Text(Localized.noQuota)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Button(Localized.setQuota) { openQuotaSetup() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
            }
        }
    }

    private func openQuotaSetup() {
        let ssid = hotspotDetector.currentConnection?.ssid
        if let profile = ssid.flatMap({ ProfileManager.shared.getProfile(ssid: $0) }) {
            editingProfile = profile
        } else {
            showProfileManager = true
        }
    }

    private var trafficSectionDivider: some View {
        HStack(spacing: TLSpace.sm) {
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
            Text(Localized.appTraffic)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
                .fixedSize()
            Image(systemName: "chevron.right")
                .font(TLFont.badge)
                .foregroundColor(TLPalette.textSecondary.opacity(0.5))
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
        }
        .contentShape(Rectangle())
        .onTapGesture { showTraffic = true }
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private var appTrafficPreview: some View {
        let top3 = Array(trafficMonitor.apps.filter { !SystemProcesses.set.contains($0.processName) }.prefix(3))
        return VStack(spacing: TLSpace.xs) {
            HStack(spacing: 0) {
                Text(Localized.process)
                    .font(TLFont.smallBold)
                    .foregroundColor(TLPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Localized.upload)
                    .font(TLFont.smallBold)
                    .foregroundColor(TLPalette.upload)
                    .frame(width: TLSize.trafficUploadCol, alignment: .trailing)
                Text(Localized.download)
                    .font(TLFont.smallBold)
                    .foregroundColor(TLPalette.download)
                    .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
            }
            ForEach(top3) { app in
                HStack(spacing: 0) {
                    Text(app.processName)
                        .font(TLFont.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatByteRate(app.bytesIn))
                        .font(TLFont.mediumMono)
                        .foregroundColor(TLPalette.upload)
                        .frame(width: TLSize.trafficUploadCol, alignment: .trailing)
                    Text(formatByteRate(app.bytesOut))
                        .font(TLFont.mediumMono)
                        .foregroundColor(TLPalette.download)
                        .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
                }
            }
            Button(Localized.showMore) { showTraffic = true }
                .buttonStyle(.plain)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.download)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture { showTraffic = true }
    }

    private var profileSection: some View {
        let currentSSID = hotspotDetector.currentConnection?.ssid
        let currentProfile = currentSSID.flatMap { ProfileManager.shared.getProfile(ssid: $0) }
        return VStack(spacing: TLSpace.sm) {
            if let profile = currentProfile {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: TLSpace.xs) {
                            Text(profile.name).font(TLFont.body)
                            if profile.isHotspot {
                                Text("(\(Localized.hotspot))").font(TLFont.body).foregroundColor(TLPalette.upload)
                            }
                        }
                        Text(profile.ssid).font(TLFont.caption).foregroundColor(TLPalette.textSecondary)
                        miniUsageStats(profile: profile)
                    }
                    Spacer()
                    Button(Localized.statistics) {
                        usageReportConfig = UsageReportConfig(preselectedProfileId: profile.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button(Localized.edit) {
                        editingProfile = profile
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            Button(Localized.manageProfiles) { showProfileManager = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
        }
    }

    /// 프로필 미니 통계 — 오늘 사용량 + 할당량 % (T-117)
    @ViewBuilder
    private func miniUsageStats(profile: Profile) -> some View {
        let today = ProfileManager.shared.getTodayUsage(profileId: profile.id)
        let usedGB = Double(today.upload + today.download) / 1_000_000_000
        let quotaGB = profile.quotaGB
        if let quotaGB = quotaGB, quotaGB > 0 {
            let pct = min(Int(usedGB * 100 / quotaGB), 999)
            HStack(spacing: TLSpace.xs) {
                ProgressView(value: min(usedGB / quotaGB, 1.0))
                    .frame(width: 70)
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
                Text("\(String(format: "%.2f", usedGB))GB / \(String(format: "%.1f", quotaGB))GB (\(pct)%)")
                    .font(TLFont.caption2)
                    .foregroundColor(pct >= 90 ? TLPalette.danger : TLPalette.textSecondary)
            }
        } else {
            Text("\(Localized.today) \(Int64(today.upload + today.download).formattedBytes)")
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
        }
    }

    private var profileManagerSheet: some View {
        VStack(spacing: TLSpace.xl) {
            Text(Localized.profileManagement)
                .font(TLFont.headline)
                .padding(.top, TLSpace.xxl)

            if profiles.isEmpty {
                Spacer()
                Text(Localized.noProfiles)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                List {
                    ForEach(profiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: TLSpace.xs) {
                                    Text(profile.name).font(TLFont.body)
                                    if profile.isHotspot {
                                        Text("(\(Localized.hotspot))").font(TLFont.body).foregroundColor(TLPalette.upload)
                                    }
                                    if profile.ssid == ssidString {
                                        Circle().fill(TLPalette.upload).frame(width: 6, height: 6)
                                        Text(Localized.connected).font(TLFont.caption2).foregroundColor(TLPalette.upload)
                                    }
                                }
                                Text(profile.ssid).font(TLFont.caption).foregroundColor(TLPalette.textSecondary)
                                let today = ProfileManager.shared.getTodayUsage(profileId: profile.id)
                                if let q = profile.quotaGB, q > 0 {
                                    let usedGB = Double(today.upload + today.download) / 1_000_000_000
                                    let pct = min(Int(usedGB * 100 / q), 999)
                                    Text("\(Localized.quota) \(String(format: "%.1f", q))GB · \(String(format: "%.2f", usedGB))GB (\(pct)%)")
                                        .font(TLFont.caption2)
                                        .foregroundColor(pct >= 90 ? TLPalette.danger : TLPalette.textSecondary)
                                } else {
                                    Text("\(Localized.today) \(Int64(today.upload + today.download).formattedBytes)")
                                        .font(TLFont.caption2)
                                        .foregroundColor(TLPalette.textSecondary)
                                }
                                if profile.ssid != ssidString {
                                    Text("\(Localized.lastConnected) \(relativeTimeString(profile.lastConnected))")
                                        .font(TLFont.caption2)
                                        .foregroundColor(TLPalette.textSecondary)
                                }
                            }
                            Spacer()
                            Button(Localized.statistics) {
                                showProfileManager = false
                                usageReportConfig = UsageReportConfig(preselectedProfileId: profile.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button(Localized.edit) {
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

            Button(Localized.close) { showProfileManager = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, TLSpace.xxl)
        }
        .frame(width: TLSize.sheetCompact, height: 300)
    }

    private var speedView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(Localized.upload)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                Text(formatSpeed(networkMonitor.currentUploadSpeed))
                    .font(TLFont.speed)
                    .foregroundColor(TLPalette.upload)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(Localized.download)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                Text(formatSpeed(networkMonitor.currentDownloadSpeed))
                    .font(TLFont.speed)
                    .foregroundColor(TLPalette.download)
            }
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: TLSpace.xl) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { summaryMode.toggle() }
            } label: {
                HStack(spacing: TLSpace.xs) {
                    Image(systemName: summaryMode ? "chevron.down" : "chevron.up")
                        .font(TLFont.caption)
                    Text(summaryMode ? Localized.detailView : Localized.summaryView)
                        .font(TLFont.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(summaryMode ? Localized.detailView : Localized.summaryView)

            Menu {
                Button(Localized.usageReport) { openStatistics() }
                Button(Localized.appTrafficButton) { showTraffic = true }
                Button(Localized.notificationList) { showNotifications = true }
                Divider()
                Button(Localized.dnsPresetApply) { showDNSPicker = true }
                Button(savingModeActive ? Localized.savingModeOn : Localized.savingModeOff) { openSavingMode() }
                Button(SavingModeManager.shared.isLowPowerMode ? Localized.lowPowerModeOn : Localized.lowPowerModeOff) {
                    // 저전력 모드 토글 (시스템 설정 열기)
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.battery")!)
                }
                Divider()
                Button(Localized.settings) { showSettings = true }
                Button(Localized.checkUpdates) { UpdaterManager.shared.openDownloadPage() }
                Button(Localized.about) { showAbout = true }
                #if DEBUG
                Divider()
                Button(Localized.debugPanel) { DebugPanelController.shared.toggle() }
                #endif
            } label: {
                Text(Localized.more)
                    .font(TLFont.caption)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
            Button(Localized.quit) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(TLPalette.danger)
        }
    }

    private func detailRow(label: String, value: String, copyValue: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(TLFont.detail)
                .foregroundColor(TLPalette.textSecondary)
                .frame(width: TLSize.detailLabelWidth, alignment: .leading)
            HStack(spacing: 3) {
                if copyValue != nil {
                    Image(systemName: "doc.on.doc")
                        .font(TLFont.small)
                        .foregroundColor(TLPalette.copyHint)
                }
                Text(value)
                    .font(TLFont.detail)
                    .foregroundColor(TLPalette.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let copyValue else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyValue, forType: .string)
            copiedIPMessage = Localized.copiedValue(copyValue)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copiedIPMessage = nil
            }
        }
    }

    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: TLSpace.sm) {
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
            Text(title).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary).fixedSize()
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
        }
    }

    private func collapsibleSectionDivider(_ title: String, isExpanded: Binding<Bool>) -> some View {
        HStack(spacing: TLSpace.sm) {
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
            Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                .font(TLFont.badge)
                .foregroundColor(TLPalette.textSecondary)
            Text(title).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary).fixedSize()
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
        }
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.wrappedValue.toggle() }
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private var dnsPresetPicker: some View {
        VStack(spacing: TLSpace.xl) {
            Text(Localized.dnsPresetPicker)
                .font(TLFont.headline)
                .padding(.top, TLSpace.xxl)

            ForEach(DNSPreset.presets) { preset in
                HStack(spacing: TLSpace.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name).font(TLFont.body)
                        Text(preset.description)
                            .font(TLFont.caption)
                            .foregroundColor(TLPalette.textSecondary)
                        Text(preset.servers.joined(separator: ", "))
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textSecondary.opacity(0.6))
                    }
                    Spacer()
                    Group {
                        if applyingPresetID == preset.id {
                            Text(Localized.dnsApplying)
                                .font(TLFont.caption)
                                .foregroundColor(TLPalette.textSecondary)
                        } else if !preset.servers.isEmpty && currentDNSServers == preset.servers {
                            Text(Localized.dnsApplied)
                                .font(TLFont.caption)
                                .foregroundColor(TLPalette.success)
                                .fontWeight(.semibold)
                        } else {
                            Button(Localized.apply) { confirmPreset = preset }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .frame(minWidth: 48, alignment: .center)
                }
                .padding(.horizontal, TLSpace.xxl)
                .padding(.vertical, TLSpace.xs)
                Divider()
            }

            if let msg = dnsStatusMessage {
                Text(msg)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
            }

            Button(Localized.close) { showDNSPicker = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, TLSpace.xxl)
        }
        .frame(width: TLSize.sheetCompact)
        .alert(item: $confirmPreset) { preset in
            Alert(
                title: Text(Localized.dnsChangeTitle),
                message: Text(Localized.dnsChangeMessage("\(preset.name) (\(preset.servers.joined(separator: ", ")))")),
                primaryButton: .cancel(Text(Localized.cancel)),
                secondaryButton: .default(Text(Localized.apply)) {
                    applyDNSPreset(preset)
                }
            )
        }
    }

    private func applyDNSPreset(_ preset: DNSPreset) {
        applyingPresetID = preset.id
        dnsStatusMessage = Localized.dnsApplying
        DNSManager.shared.applyPreset(preset) { success, message in
            DispatchQueue.main.async {
                applyingPresetID = nil
                if success {
                    dnsStatusMessage = "✓ \(message) DNS \(Localized.string("적용 완료", "Applied"))"
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
        case .pingWarning: return TLPalette.upload
        case .pingCritical: return TLPalette.danger
        case .pingRecovery, .connectionRestored: return TLPalette.success
        case .connectionLost: return TLPalette.download
        default: return TLPalette.upload
        }
    }

    private func relativeTimeString(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return Localized.justNow }
        if interval < 3600 { return Localized.minutesAgo(Int(interval / 60)) }
        if interval < 86400 { return Localized.hoursAgo(Int(interval / 3600)) }
        if interval < 604800 { return Localized.daysAgo(Int(interval / 86400)) }
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
