import SwiftUI
import Combine
import Charts

struct PopoverView: View {
    let networkMonitor: NetworkMonitor
    let hotspotDetector: HotspotDetector
    let pingMonitor: PingMonitor
    let ipResolver: IPResolver
    let locationManager: LocationManager
    let onTogglePin: (() -> Void)?
    @State private var pinned = false

    private struct PingAlert: Equatable {
        let message: String
        let type: AppNotification.NotificationType
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
    @State private var showSavingMode = false
    @State private var savingModeActive = SavingModeManager.shared.isEnabled
    @State private var showIPHistory = false
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @State private var sessionStartTime: Date?
    @State private var quotaAlertMessage: String?
    @State private var pingAlert: PingAlert?
    @State private var copiedIPMessage: String?
    @AppStorage("popover_expanded_connection_info") private var expandedConnectionInfo = false
    @AppStorage("popover_expanded_address_info") private var expandedAddressInfo = false
    @AppStorage("popover_show_app_traffic") private var showAppTraffic = true
    @AppStorage("popover_summary_mode") private var summaryMode = true
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    // publisher 정체성 고정 (body 재평가마다 새 Timer가 만들어지는 것을 방지)
    // 자동 시작(autoconnect) 대신 onAppear에서 connect, 닫힘(onDisappear)에서 cancel해 배터리 절감
    @State private var tickPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var tickSubscription: Cancellable?

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
            .sheet(isPresented: $showSavingMode) {
                SavingModeSheet(onClose: { showSavingMode = false })
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
            case "usageReport": openWindow(id: "usageReport")
            case "appTraffic": openWindow(id: "appTraffic")
            case "notifications": openWindow(id: "notifications")
            case "profileManager": showProfileManager = true
            case "dnsPreset": showDNSPicker = true
            case "savingMode": openSavingMode()
            case "settings": openSettings()
            case "about": openWindow(id: "about")
            default: break
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: TLSpace.xl) {
                headerView
                statusRow
                speedView
                qosGaugeBody
            }
            .padding(TLSpace.inset)
            ScrollView {
                VStack(spacing: TLSpace.xl) {
                    speedHistorySection
                    connectivitySection
                    interfaceSection
                    if summaryMode {
                        topProcessesSection
                    } else {
                        detailSections
                    }
                }
                .padding(.horizontal, TLSpace.inset)
                .padding(.bottom, TLSpace.sm)
            }
            // NSPopover 자동 사이징에서는 maxHeight가 무시되고 찌그러지므로 고정 높이 사용
            .frame(height: 420)
            Divider()
            bottomButtons
                .padding(.horizontal, TLSpace.inset)
                .padding(.vertical, TLSpace.xl)
        }
        .frame(width: TLSize.popoverWidth)
        .overlay(alignment: .top) {
            // 배너는 레이아웃에서 분리해 오버레이로 띄운다 — 높이 점프 방지 (자동 해제 유지)
            bannerStack
                .padding(.horizontal, TLSpace.inset)
                .padding(.top, TLSpace.sm)
        }
        .onReceive(tickPublisher) { _ in
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
            if tickSubscription == nil {
                tickSubscription = tickPublisher.connect()
            }
            // TrafficMonitor 제어는 MenuBarManager(NSPopoverDelegate)에서 담당한다.
            // (SwiftUI onAppear/onDisappear는 transient 닫힘에서 onDisappear 미호출 → acquire 누수 발생)
        }
        .onDisappear {
            tickSubscription?.cancel()
            tickSubscription = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("popoverWillShow"))) { _ in
            resetPopoverState()
        }
        .animation(.easeOut(duration: 0.2), value: quotaAlertMessage)
        .animation(.easeOut(duration: 0.2), value: pingAlert)
        .animation(.easeOut(duration: 0.2), value: copiedIPMessage)
        .animation(.easeOut(duration: 0.2), value: summaryMode)
        .animation(.easeOut(duration: 0.2), value: expandedConnectionInfo)
        .animation(.easeOut(duration: 0.2), value: expandedAddressInfo)
    }

    @ViewBuilder
    private var bannerStack: some View {
        if let msg = quotaAlertMessage {
            quotaBanner(msg)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        if let alert = pingAlert {
            pingBanner(alert)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        if let msg = copiedIPMessage {
            copiedBanner(msg)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func quotaBanner(_ msg: String) -> some View {
        HStack(spacing: TLSpace.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TLFont.caption)
                .foregroundColor(TLPalette.onUpload)
            Text(msg)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.onUpload)
            Spacer()
            Button {
                quotaAlertMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.onUpload.opacity(0.7))
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
                .foregroundColor(pingOnColor(for: alert.type))
            Text(alert.message)
                .font(TLFont.caption)
                .foregroundColor(pingOnColor(for: alert.type))
            Spacer()
            Button {
                pingAlert = nil
            } label: {
                Image(systemName: "xmark")
                    .font(TLFont.caption2)
                    .foregroundColor(pingOnColor(for: alert.type).opacity(0.7))
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
                .foregroundColor(TLPalette.onSuccess)
            Text(msg)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.onSuccess)
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
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(TLFont.headline)
                    .lineLimit(1)
                Text(connectionSubtitle)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                    .lineLimit(1)
            }
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
                openWindow(id: "notifications")
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
        }
    }

    /// 헤더 부제 — 프로필명과 SSID가 같으면 유형 표시로 중복 회피 (SSID · RSSI)
    private var connectionSubtitle: String {
        let name = displayName
        if let ssid = ssidString, ssid != name {
            if let r = hotspotDetector.currentConnection?.rssi {
                return "\(ssid) · \(r) dBm"
            }
            return ssid
        }
        if let r = hotspotDetector.currentConnection?.rssi {
            return "\(connectionTypeString) · \(r) dBm"
        }
        return connectionName
    }

    /// 상태 1행 — 배너 3종을 대체하는 단일 상태 표시 (장식 없이 도트+텍스트)
    private var statusRow: some View {
        HStack(spacing: TLSpace.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(TLFont.detail)
                .foregroundColor(statusColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        if !pingMonitor.isReachable { return TLPalette.danger }
        if let quota = currentQuota, quota.ratio >= 0.95 { return TLPalette.danger }
        if let quota = currentQuota, quota.ratio >= 0.80 { return TLPalette.upload }
        if let lat = pingMonitor.primaryLatency, lat >= 0.15 { return TLPalette.upload }
        return TLPalette.success
    }

    private var statusWord: String {
        if !pingMonitor.isReachable { return Localized.statusCritical }
        if let quota = currentQuota, quota.ratio >= 0.95 { return Localized.statusCritical }
        if let quota = currentQuota, quota.ratio >= 0.80 { return Localized.statusWarning }
        if let lat = pingMonitor.primaryLatency, lat >= 0.15 { return Localized.statusWarning }
        if pingMonitor.primaryLatency == nil && currentQuota == nil { return Localized.measuring }
        return Localized.statusNormal
    }

    private var statusText: String {
        var parts = [statusWord]
        if let lat = pingMonitor.primaryLatency {
            parts.append("\(Int(lat * 1000)) ms")
        } else if let quota = currentQuota {
            parts.append("QoS \(Int(quota.ratio * 100))%")
        }
        return parts.joined(separator: " · ")
    }

    /// 오늘 사용량 기준 (used GB, quota GB, ratio) — qosGaugeBody와 동일 기준
    private var currentQuota: (used: Double, quota: Double, ratio: Double)? {
        let ssid = hotspotDetector.currentConnection?.ssid
        guard let profile = ssid.flatMap({ ProfileManager.shared.getProfile(ssid: $0) }),
              let quotaGB = profile.quotaGB, quotaGB > 0 else { return nil }
        let today = ProfileManager.shared.getTodayUsage(profileId: profile.id)
        let used = Double(today.upload + today.download) / 1_000_000_000
        return (used, quotaGB, min(used / quotaGB, 1.0))
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
                    openWindow(id: "usageReport")
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
        .onTapGesture { openWindow(id: "appTraffic") }
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
            Button(Localized.showMore) { openWindow(id: "appTraffic") }
                .buttonStyle(.plain)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.download)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture { openWindow(id: "appTraffic") }
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
                    VStack(spacing: TLSpace.xs) {
                        Button(Localized.statistics) {
                            openWindow(id: "usageReport")
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
            }
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
                                openWindow(id: "usageReport")
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                let up = splitSpeed(networkMonitor.currentUploadSpeed)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(up.number)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                    Text(up.unit)
                        .font(TLFont.callout)
                }
                .foregroundColor(TLPalette.upload)
                HStack(spacing: 4) {
                    Circle().fill(TLPalette.upload).frame(width: 8, height: 8)
                    Text(Localized.upload)
                        .font(TLFont.caption)
                        .foregroundColor(TLPalette.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                let down = splitSpeed(networkMonitor.currentDownloadSpeed)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(down.number)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                    Text(down.unit)
                        .font(TLFont.callout)
                }
                .foregroundColor(TLPalette.download)
                HStack(spacing: 4) {
                    Text(Localized.download)
                        .font(TLFont.caption)
                        .foregroundColor(TLPalette.textSecondary)
                    Circle().fill(TLPalette.download).frame(width: 8, height: 8)
                }
            }
        }
    }

    /// 대형 속도 표시용 숫자/단위 분리 ("52" + "KB/s")
    private func splitSpeed(_ bps: Double) -> (number: String, unit: String) {
        let Bps = bps / 8
        if Bps >= 1_000_000_000 {
            return (String(format: "%.1f", Bps / 1_000_000_000), "GB/s")
        } else if Bps >= 1_000_000 {
            return (String(format: "%.1f", Bps / 1_000_000), "MB/s")
        } else if Bps >= 1_000 {
            return (String(format: "%.0f", Bps / 1_000), "KB/s")
        } else {
            return (String(format: "%.0f", Bps), "B/s")
        }
    }

    // MARK: - 프리미엄 섹션 (사용 기록·연결성·인터페이스·상위 프로세스)

    private var speedHistorySection: some View {
        VStack(alignment: .leading, spacing: TLSpace.sm) {
            sectionDivider(Localized.usageHistory)
            let history = networkMonitor.speedHistory
            if history.count >= 2 {
                let peak = max(history.map { max($0.downloadBps, $0.uploadBps) }.max() ?? 1, 1) / 8
                Chart {
                    ForEach(Array(history.enumerated()), id: \.offset) { idx, sample in
                        AreaMark(
                            x: .value("t", idx),
                            y: .value("down", sample.downloadBps / 8)
                        )
                        .foregroundStyle(TLPalette.download.opacity(0.35))
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("t", idx),
                            y: .value("up", sample.uploadBps / 8)
                        )
                        .foregroundStyle(TLPalette.upload.opacity(0.35))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...(peak * 1.15))
                .frame(height: 110)
                .overlay(alignment: .topLeading) {
                    Text(formatByteRate(Int64(peak)))
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.textSecondary)
                }
            } else {
                Text(Localized.measuring)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
            }
        }
    }

    private var connectivitySection: some View {
        VStack(alignment: .leading, spacing: TLSpace.sm) {
            sectionDivider(Localized.connectivityHistory)
            HStack(spacing: 4) {
                ForEach(Array(pingMonitor.recentPingOutcomes.suffix(20).enumerated()), id: \.offset) { _, ok in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ok ? TLPalette.success : TLPalette.separator)
                        .frame(width: 10, height: 10)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var interfaceSection: some View {
        VStack(alignment: .leading, spacing: TLSpace.sm) {
            sectionDivider(Localized.interfaceInfo)
            interfaceRow(label: Localized.totalUpload, value: networkMonitor.totalUpload.formattedBytes)
            interfaceRow(label: Localized.totalDownload, value: networkMonitor.totalDownload.formattedBytes)
            HStack {
                Text(Localized.status)
                    .font(TLFont.detail)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
                statusPill
            }
            interfaceRow(label: Localized.latencyTitle, value: latencyText)
            interfaceRow(label: Localized.jitterTitle, value: jitterText)
            interfaceRow(label: Localized.interfaceInfo, value: interfaceText)
            if let mac = macText {
                interfaceRow(label: Localized.macAddress, value: mac)
            }
        }
    }

    private func interfaceRow(label: String, value: String, valueColor: Color = TLPalette.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(TLFont.detail)
                .foregroundColor(TLPalette.textSecondary)
            Spacer()
            Text(value)
                .font(TLFont.detail.monospacedDigit())
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
    }

    private var statusPill: some View {
        let up = pingMonitor.isReachable
        return Text(up ? Localized.upState : Localized.downState)
            .font(TLFont.medium.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(up ? TLPalette.success : TLPalette.danger, in: Capsule())
    }

    private var latencyText: String {
        if let lat = pingMonitor.primaryLatency {
            return "\(Int(lat * 1000)) ms"
        }
        return Localized.measuring
    }

    private var jitterText: String {
        if let j = pingMonitor.jitter {
            return String(format: "%.0f ms", j * 1000)
        }
        return "--"
    }

    private var interfaceText: String {
        let name = hotspotDetector.currentConnection?.interfaceName ?? "-"
        return "\(connectionTypeString) (\(name))"
    }

    private var macText: String? {
        guard let name = hotspotDetector.currentConnection?.interfaceName else { return nil }
        return networkMonitor.macAddress(forInterface: name)
    }

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: TLSpace.xs) {
            HStack(spacing: TLSpace.sm) {
                Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
                Text(Localized.topProcesses)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(TLFont.badge)
                    .foregroundColor(TLPalette.textSecondary.opacity(0.5))
                Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
            }
            .contentShape(Rectangle())
            .onTapGesture { openWindow(id: "appTraffic") }
            if showAppTraffic, !trafficMonitor.apps.isEmpty {
                HStack(spacing: TLSpace.sm) {
                    Text(Localized.process)
                        .font(TLFont.smallBold)
                        .foregroundColor(TLPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Circle().fill(TLPalette.upload).frame(width: 8, height: 8)
                    Circle().fill(TLPalette.download).frame(width: 8, height: 8)
                }
                ForEach(topProcessRows) { app in
                    HStack(spacing: TLSpace.sm) {
                        procIcon(app.processName)
                        Text(app.processName)
                            .font(TLFont.medium)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatByteRate(app.bytesOut))
                            .font(TLFont.mediumMono)
                            .foregroundColor(TLPalette.upload)
                            .frame(width: 76, alignment: .trailing)
                        Text(formatByteRate(app.bytesIn))
                            .font(TLFont.mediumMono)
                            .foregroundColor(TLPalette.download)
                            .frame(width: 76, alignment: .trailing)
                    }
                }
            } else {
                Text(Localized.trafficCollecting)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var topProcessRows: [TrafficMonitor.AppTraffic] {
        Array(trafficMonitor.apps
            .sorted { $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut }
            .prefix(5))
    }

    private func procIcon(_ name: String) -> some View {
        Group {
            if let nsImage = AppIconResolver.icon(forProcess: name) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app")
                    .foregroundColor(TLPalette.textSecondary)
            }
        }
        .frame(width: 16, height: 16)
    }

    private var bottomButtons: some View {
        HStack(spacing: TLSpace.md) {
            Button(Localized.usageReport) { openWindow(id: "usageReport") }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(Localized.usageReport)

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
                Button(Localized.appTrafficButton) { openWindow(id: "appTraffic") }
                Button(Localized.notificationList) { openWindow(id: "notifications") }
                Button(Localized.manageProfiles) { showProfileManager = true }
                Divider()
                Button(Localized.dnsPresetApply) { showDNSPicker = true }
                Button(savingModeActive ? Localized.savingModeOn : Localized.savingModeOff) { openSavingMode() }
                Button(SavingModeManager.shared.isLowPowerMode ? Localized.lowPowerModeOn : Localized.lowPowerModeOff) {
                    // 저전력 모드 토글 (시스템 설정 열기)
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.battery")!)
                }
                Divider()
                Button(Localized.settings) { openSettings() }
                Button(Localized.checkUpdates) { UpdaterManager.shared.openDownloadPage() }
                Button(Localized.about) { openWindow(id: "about") }
                #if DEBUG
                Divider()
                Button(Localized.debugPanel) { DebugPanelController.shared.toggle() }
                #endif
            } label: {
                Image(systemName: "ellipsis")
                    .font(TLFont.caption)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(Localized.more)
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(TLFont.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(TLPalette.danger)
            .help(Localized.quit)
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
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
        }
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

    private func pingOnColor(for type: AppNotification.NotificationType) -> Color {
        switch type {
        case .pingWarning: return TLPalette.onUpload
        case .pingCritical: return TLPalette.onDanger
        case .pingRecovery, .connectionRestored: return TLPalette.onSuccess
        case .connectionLost: return TLPalette.onDownload
        default: return TLPalette.onUpload
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

    private func openSavingMode() {
        showSavingMode = true
    }

    /// 팝오버가 열릴 때 남아있던 시트 상태(좀비)를 전부 초기화한다.
    /// admin 프롬프트(절약 모드/DNS 프리셋)로 인한 resignActive → popover 강제 닫힘 후
    /// 재오픈할 때 이전 @State 시트 flag가 남아 클릭이 죽는 현상을 방지한다.
    func resetPopoverState() {
        showDNSPicker = false
        dnsStatusMessage = nil
        confirmPreset = nil
        applyingPresetID = nil
        showProfileManager = false
        editingProfile = nil
        showSavingMode = false
        showIPHistory = false
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
