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

    /// 설정·연결 변화로 body 를 다시 평가시키기 위한 신호.
    ///
    /// 예전엔 1Hz Timer 로 `tick` 을 갱신했는데, 그 값을 읽는 계산 프로퍼티
    /// (`sessionDurationString`) 가 v0.39 에서 대시보드로 옮겨져 **쓰이지 않게 됐다**.
    /// 그 결과 매초 팝오버 body 전체가 재평가될 뿐 세션 경과는 어디에도 안 보였다 (T-250 #10).
    /// 1초마다 갱신이 필요한 값은 `DashboardClock` 처럼 하위 서브뷰로 격리한다.
    @State private var refreshToken = 0
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
    @ObservedObject private var updater = UpdaterManager.shared
    @State private var sessionStartTime: Date?
    @State private var quotaAlertMessage: String?
    @State private var pingAlert: PingAlert?
    @State private var copiedIPMessage: String?
    @AppStorage("showCPUGraph") private var showCPUGraph = false
    @AppStorage("showGPUGraph") private var showGPUGraph = false
    @AppStorage("showMemGraph") private var showMemGraph = true
    @AppStorage("appTraffic_show_system") private var showSystemProcesses = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings



    var body: some View {
        mainContent
            .sheet(isPresented: $showDNSPicker) {
                dnsPresetPicker
                    .onAppear {
                        applyingPresetID = nil
                        dnsStatusMessage = nil
                        Task {
                            currentDNSServers = await DNSManager.shared.currentServersAsync()
                        }
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
            refreshToken &+= 1
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
                refreshToken &+= 1
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
        // `refreshToken` 은 읽는 곳이 없다 — 의도적으로 "쓰기 전용"이다.
        // @AppStorage 가 아닌 설정값은 값이 바뀐 걸 알 수가 없어, 알림마다 이 신호로
        // body 재평가를 강제한다. 제거하면 설정 변경이 화면에 반영되지 않는다.
        let _ = refreshToken
        return VStack(spacing: 0) {
            VStack(spacing: TLSpace.xl) {
                headerView
                statusRow
                speedView
                // 프로세스 리스트는 **고정 영역**에 둔다 — 스크롤 없이 항상 보인다.
                // "대역폭이 왜 이렇게 나오지? → 누가 쓰지?" 의 답이 여기 있다.
                // v0.39 에서 대시보드 통합 명목으로 사라졌으나, 핵심 시나리오가 이 창에 있다.
                NetworkProcessList(
                    apps: trafficMonitor.apps,
                    windowSeconds: trafficMonitor.windowSeconds,
                    limit: 3,
                    showSystem: showSystemProcesses,
                    onShowMore: { openWindow(id: "appTraffic") }
                )
                qosGaugeBody
            }
            .padding(TLSpace.inset)
            // 사용 기록·연결성은 고정 영역에 둔다 — 인터페이스부터만 스크롤
            VStack(spacing: TLSpace.xl) {
                speedHistorySection
                connectivitySection
            }
            .padding(.horizontal, TLSpace.inset)
            .padding(.bottom, TLSpace.xl)
            ScrollView {
                VStack(spacing: TLSpace.xl) {
                    interfaceSection
                }
                .padding(.horizontal, TLSpace.inset)
                .padding(.bottom, TLSpace.sm)
            }
            // v0.39 — 상세 보기 토글 제거(대시보드로 통합). 스크롤 영역은 인터페이스 섹션만 남는다.
            .frame(height: 92)
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
        .onReceive(NotificationCenter.default.publisher(for: .init("connectionChanged"))) { _ in
            hotspotDetector.refreshNow()
            refreshToken &+= 1
            profiles = ProfileManager.shared.getAllProfiles()
            updateSessionStartTime()
        }
        .onAppear {
            updateSessionStartTime()
            // TrafficMonitor 제어는 MenuBarManager(NSPopoverDelegate)에서 담당한다.
            // (SwiftUI onAppear/onDisappear는 transient 닫힘에서 onDisappear 미호출 → acquire 누수 발생)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("popoverWillShow"))) { _ in
            resetPopoverState()
            // 팝오버를 열 때 주기에 맞춰 조용히 최신 버전을 확인한다
            Task { await updater.maybeAutoCheckForUpdate() }
        }
        .animation(.easeOut(duration: 0.2), value: quotaAlertMessage)
        .animation(.easeOut(duration: 0.2), value: pingAlert)
        .animation(.easeOut(duration: 0.2), value: copiedIPMessage)
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
    /// 우측에는 게이트웨이·외부 IP 칩을 상시 노출해 간략 보기에서도 1클릭 복사 (v0.35.1 QuickCopy)
    private var statusRow: some View {
        HStack(spacing: TLSpace.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(TLFont.detail)
                .foregroundColor(statusColor)
                .lineLimit(1)
            Spacer(minLength: TLSpace.sm)
            quickGatewayChip
            quickIPChip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu { quickCopyMenu }
    }

    /// 상태행 외부 IP 칩 왼쪽 게이트웨이 칩 — 탭하면 즉시 복사
    private var quickGatewayChip: some View {
        Group {
            if let gw = hotspotDetector.currentConnection?.gatewayIP {
                Button {
                    copyToPasteboard(gw, source: "statusChip")
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "network")
                            .font(TLFont.small)
                            .foregroundColor(TLPalette.textSecondary)
                        Text(gw)
                            .font(TLFont.detail.monospacedDigit())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "doc.on.doc")
                            .font(TLFont.small)
                            .foregroundColor(TLPalette.copyHint)
                    }
                }
                .buttonStyle(.plain)
                .help(Localized.copyGatewayHelp)
                .pointingHandCursor()
            }
        }
    }

    /// 상태행 우측 외부 IP 칩 — 탭하면 즉시 복사
    private var quickIPChip: some View {
        Group {
            if let extIP = ipResolver.externalIP {
                Button {
                    copyToPasteboard(extIP, source: "statusChip")
                } label: {
                    HStack(spacing: 3) {
                        if let flag = GeoIPInfo.flagEmoji(forCountryCode: ipResolver.geoInfo?.countryCode) {
                            Text(flag)
                                .font(TLFont.detail)
                        }
                        Text(extIP)
                            .font(TLFont.detail.monospacedDigit())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "doc.on.doc")
                            .font(TLFont.small)
                            .foregroundColor(TLPalette.copyHint)
                    }
                }
                .buttonStyle(.plain)
                .help(Localized.copyExternalIPHelp)
                .pointingHandCursor()
            } else {
                Text("—")
                    .font(TLFont.detail.monospacedDigit())
                    .foregroundColor(TLPalette.textSecondary)
                    .help(Localized.measuring)
            }
        }
    }

    /// 상태행·속도 영역 우클릭 메뉴 — 자주 복사하는 주소 모음 (v0.35.1 QuickCopy)
    @ViewBuilder
    private var quickCopyMenu: some View {
        Button(Localized.copyExternalIP) {
            if let ip = ipResolver.externalIP { copyToPasteboard(ip, source: "menu") }
        }
        .disabled(ipResolver.externalIP == nil)
        Button(Localized.copyInternalIP) {
            if let ip = hotspotDetector.currentConnection?.localIP { copyToPasteboard(ip, source: "menu") }
        }
        .disabled(hotspotDetector.currentConnection?.localIP == nil)
        Button(Localized.copyGateway) {
            if let gw = hotspotDetector.currentConnection?.gatewayIP { copyToPasteboard(gw, source: "menu") }
        }
        .disabled(hotspotDetector.currentConnection?.gatewayIP == nil)
        Button(Localized.copySSID) {
            if let ssid = ssidString { copyToPasteboard(ssid, source: "menu") }
        }
        .disabled(ssidString == nil)
        Button(Localized.copyBSSID) {
            if let bssid = bssidString { copyToPasteboard(bssid, source: "menu") }
        }
        .disabled(bssidString == nil)
    }

    /// 클립보드 복사 공용 헬퍼 — detailRow/칩/메뉴가 공유
    private func copyToPasteboard(_ value: String, source: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedIPMessage = Localized.copiedValue(value)
        DebugLogger.shared.action("UI", "[FEATURE] QuickCopy 복사 (source=\(source))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedIPMessage = nil
        }
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


    /// 프로필 미니 통계 — 오늘 사용량 + 할당량 % (T-117)
    @ViewBuilder
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
            TLNetworkSpeedChart(
                history: networkMonitor.speedHistory,
                uploadBitRate: networkMonitor.currentUploadSpeed,
                downloadBitRate: networkMonitor.currentDownloadSpeed
            )
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
    private var bottomButtons: some View {
        HStack(spacing: TLSpace.md) {
            // v0.39 — 주 버튼을 '대시보드'로 상향. 상세 보기 토글은 제거되었다(대시보드로 통합).
            Button(Localized.dashboard) { openWindow(id: "dashboard") }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(Localized.dashboard)

            Menu {
                Button(Localized.usageReport) { openWindow(id: "usageReport") }
                Button(Localized.appTrafficButton) { openWindow(id: "appTraffic") }
                Button(Localized.notificationList) { openWindow(id: "notifications") }
                Button(FloatingWindowController.shared.isVisible ? Localized.floatingWindowHide : Localized.floatingWindowShow) {
                    FloatingWindowController.shared.toggle()
                }
                Divider()
                Button(Localized.networkDiagnostics) { DiagnosticsWindowController.shared.show() }
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
                Button(Localized.checkUpdates) {
                    NotificationCenter.default.post(name: .init("manualUpdateCheck"), object: nil)
                }
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
            copyToPasteboard(copyValue, source: "detailRow")
        }
    }

    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: TLSpace.sm) {
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
            Text(title).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary).fixedSize()
            Rectangle().frame(height: 1).foregroundColor(TLPalette.separator)
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
