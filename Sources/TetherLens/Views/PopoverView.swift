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
            collapsibleSectionDivider(Localized.connectionInfo, isExpanded: $expandedConnectionInfo)
            connectionInfoView
            collapsibleSectionDivider(Localized.addressInfo, isExpanded: $expandedAddressInfo)
            connectionAddressView
            sectionDivider(Localized.qosGauge)
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
            sectionDivider(Localized.profile)
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
            Text(displayName)
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
                .help(pinned ? Localized.unpin : Localized.pinPopover)
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
            .fill(pingMonitor.isReachable ? Color.green : Color.red)
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
        VStack(alignment: .leading, spacing: 6) {
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
        VStack(alignment: .leading, spacing: 6) {
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
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                }
            }
            if expandedAddressInfo {
                if let dns = hotspotDetector.currentConnection?.dnsServers, !dns.isEmpty {
                    detailRow(label: Localized.dns, value: dns.joined(separator: ", "))
                        .onTapGesture { showDNSPicker = true }
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
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "location.slash")
                .font(.caption2)
                .foregroundColor(.orange)
                .padding(.top, 2)
            if !LocationManager.systemLocationServicesEnabled {
                Text(Localized.locationServiceOff)
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(Localized.openSettings) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                Text(Localized.locationAppDenied)
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(Localized.openSettings) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else if !locationManager.isAuthorized {
                Text(Localized.locationNeeded)
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(Localized.requestPermission) {
                    locationManager.requestAuthorization()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            } else {
                Text(Localized.locationProvisioning)
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(Localized.openSettings) {
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
                Text(Localized.noQuota)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private var trafficSectionDivider: some View {
        HStack(spacing: 6) {
            Rectangle().frame(height: 1).foregroundColor(Color(nsColor: .separatorColor))
            Text(Localized.appTraffic)
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
                Text(Localized.process)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Localized.upload)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .frame(width: 62, alignment: .trailing)
                Text(Localized.download)
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
            Button(Localized.showMore) { showTraffic = true }
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
                        HStack(spacing: 4) {
                            Text(profile.name).font(.body)
                            if profile.isHotspot {
                                Text("(\(Localized.hotspot))").font(.body).foregroundColor(.orange)
                            }
                        }
                        Text(profile.ssid).font(.caption).foregroundColor(.secondary)
                        if let q = profile.quotaGB {
                            Text("\(Localized.quota) \(String(format: "%.1f", q))GB").font(.caption2).foregroundColor(.secondary)
                        }
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

    private var profileManagerSheet: some View {
        VStack(spacing: 12) {
            Text(Localized.profileManagement)
                .font(.headline)
                .padding(.top, 16)

            if profiles.isEmpty {
                Spacer()
                Text(Localized.noProfiles)
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
                                    if profile.isHotspot {
                                        Text("(\(Localized.hotspot))").font(.body).foregroundColor(.orange)
                                    }
                                    if profile.ssid == ssidString {
                                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                                        Text(Localized.connected).font(.caption2).foregroundColor(.orange)
                                    }
                                }
                                Text(profile.ssid).font(.caption).foregroundColor(.secondary)
                                if let q = profile.quotaGB {
                                    Text("\(Localized.quota) \(String(format: "%.1f", q))GB").font(.caption2)
                                }
                                if profile.ssid != ssidString {
                                    Text("\(Localized.lastConnected) \(relativeTimeString(profile.lastConnected))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
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
                .padding(.bottom, 16)
        }
        .frame(width: 280, height: 300)
    }

    private var speedView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(Localized.upload)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatSpeed(networkMonitor.currentUploadSpeed))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.orange)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(Localized.download)
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
                Button(Localized.usageReport) { openStatistics() }
                Button(Localized.appTrafficButton) { showTraffic = true }
                Button(Localized.notificationList) { showNotifications = true }
                Divider()
                Button(Localized.dnsPresetApply) { showDNSPicker = true }
                Button(savingModeActive ? Localized.savingModeOn : Localized.savingMode) { openSavingMode() }
                Divider()
                Button(Localized.settings) { showSettings = true }
                Button(Localized.checkUpdates) { UpdaterManager.shared.checkForUpdates() }
                Button(Localized.about) { showAbout = true }
                #if DEBUG
                Divider()
                Button(Localized.debugPanel) { DebugPanelController.shared.toggle() }
                #endif
            } label: {
                Text(Localized.more)
                    .font(.caption)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
            Button(Localized.donate) { openDonation() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(Localized.quit) { NSApplication.shared.terminate(nil) }
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
            copiedIPMessage = Localized.copiedValue(copyValue)
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
            Text(Localized.dnsPresetPicker)
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
                            Text(Localized.dnsApplying)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if !preset.servers.isEmpty && currentDNSServers == preset.servers {
                            Text(Localized.dnsApplied)
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        } else {
                            Button(Localized.apply) { confirmPreset = preset }
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

            Button(Localized.close) { showDNSPicker = false }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, 16)
        }
        .frame(width: 260)
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
        case .pingWarning: return .orange
        case .pingCritical: return .red
        case .pingRecovery, .connectionRestored: return .green
        case .connectionLost: return .blue
        default: return .orange
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
