import AppKit
import SwiftUI
import UserNotifications

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
class MenuBarManager: NSObject, @unchecked Sendable {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var timer: Timer?
    private var cacheTimer: Timer?
    private var locationTimer: Timer?

    private let networkMonitor = NetworkMonitor()
    private let hotspotDetector = HotspotDetector()
    private let pingMonitor = PingMonitor()
    private let ipResolver = IPResolver()
    private let locationManager: LocationManager

    private let menuBarView = MenuBarView()

    private let connectionChanged = Notification.Name("connectionChanged")
    private var lastAutoRegisterSSID: String?
    private var recordTimer: Timer?
    private var ipRefreshTimer: Timer?
    private static let notifiedThresholdsKey = "quota_notified_thresholds"

    private let notiDelegate = NotificationDelegate()

    private var lastTrackedSSID: String?
    private var currentSession: Session?
    private var isMonitoring = false
    private var debugPanelMonitor: Any?

    private var cachedProfile: Profile?
    private var cachedUsage: (upload: Int64, download: Int64)?
    private var cachedTotalUsage: (upload: Int64, download: Int64)?
    private var cacheNeedsInvalidation = false
    private var pendingIPLog: (ip: String, country: String?, latitude: Double?, longitude: Double?)?

    private(set) var popoverPinned = false

    var currentSessionDuration: TimeInterval? {
        guard let session = currentSession else { return nil }
        return Date().timeIntervalSince(session.startTime)
    }

    init(locationManager: LocationManager) {
        self.locationManager = locationManager

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient

        super.init()

        UNUserNotificationCenter.current().delegate = notiDelegate

        setupMenuBar()
        setupPopover()
        setupLocationCallback()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCurrentProfileDeleted),
            name: .init("currentProfileDeleted"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAppTermination),
            name: NSApplication.willTerminateNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSettingsChanged),
            name: .init("settingsChanged"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResignActive),
            name: NSApplication.didResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSystemSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    /// 시스템 슬립 진입 — 모든 폴링을 일시중지한다 (배터리/CPU 절감).
    @objc private func handleSystemSleep() {
        guard isMonitoring else { return }
        DebugLogger.shared.system("Power", "시스템 슬립 - 모니터링 일시중지")
        // 슬립 직전 마지막 사용량을 기록해 슬립 구간 유실을 방지
        recordCurrentUsage()
        suspendTimers()
        networkMonitor.stop()
        hotspotDetector.stop()
        pingMonitor.stop()
        TrafficMonitor.shared.stop()
        locationManager.stopUpdating()
    }

    /// 시스템 깨어남 — 폴링을 재개한다.
    @objc private func handleSystemWake() {
        guard isMonitoring else { return }
        DebugLogger.shared.system("Power", "시스템 깨어남 - 모니터링 재개")
        cacheNeedsInvalidation = true
        networkMonitor.start()
        hotspotDetector.start()
        pingMonitor.start()
        TrafficMonitor.shared.start()
        locationManager.startUpdating()
        setupTimers()
        refreshCache()
        updateMenuBarText()
        NotificationCenter.default.post(name: connectionChanged, object: nil)
    }

    private func suspendTimers() {
        timer?.invalidate()
        timer = nil
        cacheTimer?.invalidate()
        cacheTimer = nil
        recordTimer?.invalidate()
        recordTimer = nil
        ipRefreshTimer?.invalidate()
        ipRefreshTimer = nil
        locationTimer?.invalidate()
        locationTimer = nil
    }

    @objc private func handleSettingsChanged() {
        guard isMonitoring else { return }
        timer?.invalidate()
        timer = nil
        cacheTimer?.invalidate()
        cacheTimer = nil
        recordTimer?.invalidate()
        recordTimer = nil
        ipRefreshTimer?.invalidate()
        ipRefreshTimer = nil
        locationTimer?.invalidate()
        locationTimer = nil
        TrafficMonitor.shared.stop()
        TrafficMonitor.shared.start()
        setupTimers()
        cacheNeedsInvalidation = true
        refreshCache()
        updateMenuBarText()
    }

    @objc private func handleResignActive() {
        guard popover.isShown, !popoverPinned else { return }
        popover.performClose(nil)
    }

    @objc private func handleCurrentProfileDeleted() {
        guard let ssid = hotspotDetector.currentConnection?.ssid, !ssid.isEmpty else { return }
        lastAutoRegisterSSID = nil
        cacheNeedsInvalidation = true
        refreshCache()
        // 삭제된 프로필의 세션을 계속 참조하면 recordUsage가 FK 위반으로 크래시할 수 있다.
        // lastTrackedSSID를 무효화해 다음 updateMenuBarText에서 새 프로필로 세션을 다시 열도록 한다.
        currentSession = nil
        lastTrackedSSID = nil
        if SettingsManager.shared.autoSwitchProfile {
            _ = ProfileManager.shared.autoRegisterIfNeeded(ssid: ssid, connectionType: connectionTypeString(for: hotspotDetector.currentConnection?.type))
        }
        updateMenuBarText()
        NotificationCenter.default.post(name: connectionChanged, object: nil)
    }

    @objc private func handleAppTermination() {
        recordCurrentUsage()
        ProfileManager.shared.endAllActiveSessions()
        TrafficMonitor.shared.flushBeforeTermination()
        stopMonitoring()
    }

    private func setupLocationCallback() {
        locationManager.onAuthorizationChange = { [weak self] authorized in
            guard let self else { return }
            hotspotDetector.refreshNow()
            updateMenuBarText()
            NotificationCenter.default.post(name: connectionChanged, object: nil)
        }
    }

    private func setupMenuBar() {
        menuBarView.onClick = { [weak self] in self?.togglePopover() }
        menuBarView.onRightClick = { [weak self] in self?.showMoreMenu() }
        statusItem.view = menuBarView
        updateMenuBarText()
    }

    private func showMoreMenu() {
        let menu = NSMenu()
        let lowPower = SavingModeManager.shared.isLowPowerMode
        menu.addItem(moreMenuItem(Localized.usageReport) { [weak self] in
            self?.openPopoverAndTrigger("usageReport")
        })
        menu.addItem(moreMenuItem(Localized.appTrafficButton) { [weak self] in
            self?.openPopoverAndTrigger("appTraffic")
        })
        menu.addItem(moreMenuItem(Localized.notificationList) { [weak self] in
            self?.openPopoverAndTrigger("notifications")
        })
        menu.addItem(.separator())
        menu.addItem(moreMenuItem(Localized.dnsPresetApply) { [weak self] in
            self?.openPopoverAndTrigger("dnsPreset")
        })
        let savingLabel = SavingModeManager.shared.isEnabled ? Localized.savingModeOn : Localized.savingModeOff
        menu.addItem(moreMenuItem(savingLabel) { [weak self] in
            self?.openPopoverAndTrigger("savingMode")
        })
        menu.addItem(moreMenuItem(lowPower ? Localized.lowPowerModeOn : Localized.lowPowerModeOff) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.battery")!)
        })
        menu.addItem(.separator())
        menu.addItem(moreMenuItem(Localized.settings) { [weak self] in
            self?.openPopoverAndTrigger("settings")
        })
        menu.addItem(moreMenuItem(Localized.checkUpdates) {
            UpdaterManager.shared.openDownloadPage()
        })
        menu.addItem(moreMenuItem(Localized.about) { [weak self] in
            self?.openPopoverAndTrigger("about")
        })
        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(moreMenuItem(Localized.debugPanel) {
            DebugPanelController.shared.toggle()
        })
        #endif

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        } else {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: menuBarView.bounds.height + 4), in: menuBarView)
        }
    }

    private func moreMenuItem(_ title: String, _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(moreMenuAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = handler
        return item
    }

    @objc private func moreMenuAction(_ sender: NSMenuItem) {
        (sender.representedObject as? () -> Void)?()
    }

    private func openPopoverAndTrigger(_ action: String) {
        if !popover.isShown {
            togglePopover()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .init("moreAction"), object: nil, userInfo: ["action": action])
        }
    }

    private func setupPopover() {
        let contentView = PopoverView(
            networkMonitor: networkMonitor,
            hotspotDetector: hotspotDetector,
            pingMonitor: pingMonitor,
            ipResolver: ipResolver,
            locationManager: locationManager,
            onTogglePin: { [weak self] in self?.togglePin() }
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        authorizeNotifications()

        setupDebugPanelShortcut()
        DebugLogger.shared.system("App", "앱 시작됨")

        ipResolver.onIPChange = { [weak self] oldIP, newIP, geo in
            guard let self else { return }
            if let profileId = self.cachedProfile?.id {
                DebugLogger.shared.action("Network", "외부 IP 변경: \(oldIP ?? "없음") → \(newIP)")
                ProfileManager.shared.addIPLog(profileId: profileId, ipAddress: newIP, country: geo?.country, latitude: geo?.latitude, longitude: geo?.longitude)
                NotificationCenter.default.post(name: .init("ipChanged"), object: nil)
            } else {
                self.pendingIPLog = (newIP, geo?.country, geo?.latitude, geo?.longitude)
            }
        }

        networkMonitor.start()
        hotspotDetector.start()
        pingMonitor.start()
        TrafficMonitor.shared.start()

        ProfileManager.shared.cleanupOldLogs()
        ProfileManager.shared.mergeStaleIPLogs()
        ProfileManager.shared.cleanupAppTrafficLogs()
        ProfileManager.shared.endAllActiveSessions()
        NotificationCenter.default.post(name: .init("sessionChanged"), object: nil)

        refreshCache()

        if let ssid = hotspotDetector.currentConnection?.ssid,
           let profile = cachedProfile {
            currentSession = ProfileManager.shared.getActiveSession(profileId: profile.id)
            if currentSession == nil {
                currentSession = ProfileManager.shared.startSession(
                    profileId: profile.id,
                    latitude: bestLocation.latitude,
                    longitude: bestLocation.longitude,
                    locationSource: bestLocation.source
                )
            }
            ProfileManager.shared.resetCounter(
                profileId: profile.id,
                totalUpload: networkMonitor.totalUpload,
                totalDownload: networkMonitor.totalDownload
            )
            lastTrackedSSID = ssid
            // IP가 이미 조회된 경우 (이전 실행에서 캐시) 첫 로그 기록
            if let ip = ipResolver.externalIP {
                let geo = ipResolver.geoInfo
                ProfileManager.shared.addIPLog(profileId: profile.id, ipAddress: ip, country: geo?.country, latitude: geo?.latitude, longitude: geo?.longitude)
            }
            // onIPChange가 프로필 없이 먼저 불린 경우
            if let pending = pendingIPLog {
                ProfileManager.shared.addIPLog(profileId: profile.id, ipAddress: pending.ip, country: pending.country, latitude: pending.latitude, longitude: pending.longitude)
                pendingIPLog = nil
            }
        }

        Task {
            for _ in 0..<15 {
                if hotspotDetector.isNetworkAvailable { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await ipResolver.refresh()
        }

        isMonitoring = true
        setupTimers()
    }

    private func setupTimers() {
        recordTimer = scheduleTimer(300) { [weak self] in
            self?.recordCurrentUsage()
        }

        ipRefreshTimer = scheduleTimer(1800) { [weak self] in
            Task { [weak self] in
                guard let self else { return }
                if SavingModeManager.shared.isLowPowerMode {
                    await DebugLogger.shared.system("Power", "저전력 모드 - IP 갱신 건너뜀")
                } else {
                    await self.ipResolver.refresh()
                }
            }
        }

        locationTimer = scheduleTimer(300) { [weak self] in
            guard let self else { return }
            if SavingModeManager.shared.isLowPowerMode {
                self.locationManager.stopUpdating()
            } else {
                self.locationManager.startUpdating()
            }
        }

        cacheTimer = scheduleTimer(SettingsManager.shared.cacheRefreshInterval) { [weak self] in
            self?.refreshCache()
        }

        timer = scheduleTimer(SettingsManager.shared.menuBarRefreshInterval) { [weak self] in
            self?.updateMenuBarText()
        }
    }

    private func scheduleTimer(_ interval: Double, _ block: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                block()
            }
        }
        // 타이머 병합으로 전력 절감 — 반복 주기의 10% 허용 오차
        timer.tolerance = max(interval * 0.1, 0.05)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    func stopMonitoring() {
        DebugLogger.shared.system("App", "모니터링 중지")
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        cacheTimer?.invalidate()
        cacheTimer = nil
        recordTimer?.invalidate()
        recordTimer = nil
        ipRefreshTimer?.invalidate()
        ipRefreshTimer = nil
        locationTimer?.invalidate()
        locationTimer = nil
        if let monitor = debugPanelMonitor {
            NSEvent.removeMonitor(monitor)
            debugPanelMonitor = nil
        }
        networkMonitor.stop()
        hotspotDetector.stop()
        pingMonitor.stop()
        TrafficMonitor.shared.stop()
        locationManager.stopUpdating()
    }

    private func recordCurrentUsage() {
        guard let ssid = hotspotDetector.currentConnection?.ssid,
              let profile = ProfileManager.shared.getProfile(ssid: ssid) else { return }
        ProfileManager.shared.recordUsage(
            totalUpload: networkMonitor.totalUpload,
            totalDownload: networkMonitor.totalDownload,
            profileId: profile.id,
            sessionId: currentSession?.id
        )
    }

    private func refreshCache() {
        if cacheNeedsInvalidation {
            cachedProfile = nil
            cachedUsage = nil
            cachedTotalUsage = nil
            cacheNeedsInvalidation = false
        }
        let ssid = hotspotDetector.currentConnection?.ssid
        guard let ssid = ssid, !ssid.isEmpty else {
            cachedProfile = nil
            cachedUsage = nil
            cachedTotalUsage = nil
            return
        }
        cachedProfile = ProfileManager.shared.getProfile(ssid: ssid)
        if let pid = cachedProfile?.id {
            cachedUsage = ProfileManager.shared.getTodayUsage(profileId: pid)
            cachedTotalUsage = ProfileManager.shared.getTotalUsage(profileId: pid)
        } else {
            cachedUsage = nil
            cachedTotalUsage = nil
        }
    }

    private func updateMenuBarText() {
        let upload = networkMonitor.currentUploadSpeed
        let download = networkMonitor.currentDownloadSpeed
        let uploadStr = formatSpeed(upload)
        let downloadStr = formatSpeed(download)

        let ssid = hotspotDetector.currentConnection?.ssid
        if let conn = hotspotDetector.currentConnection {
            switch conn.type {
            case .iOSPersonalHotspot, .androidHotspot:
                pingMonitor.isHotspot = true
            default:
                pingMonitor.isHotspot = false
            }
        }
        var totalQuotaGB: Double?
        var totalStr = ""
        var remainingStr = ""
        var todayGB: Double = 0

        if let ssid = ssid, !ssid.isEmpty {
            if ssid != lastAutoRegisterSSID {
                lastAutoRegisterSSID = ssid
                // SSID가 바뀌었으므로 이전 프로필의 스테일 캐시는 자동 전환 여부와 무관하게 무효화.
                // 그렇지 않으면 autoSwitchProfile OFF 상태에서 이전 프로필로 새 세션이 열려 트래픽이 오염된다.
                cachedProfile = nil
                cachedUsage = nil
                cachedTotalUsage = nil
                cacheNeedsInvalidation = true
                if SettingsManager.shared.autoSwitchProfile {
                    _ = ProfileManager.shared.autoRegisterIfNeeded(ssid: ssid, connectionType: connectionTypeString(for: hotspotDetector.currentConnection?.type))
                }
            }

            let profile = cachedProfile ?? ProfileManager.shared.getProfile(ssid: ssid)
            totalQuotaGB = profile?.quotaGB

            if ssid != lastTrackedSSID {
                if let oldSession = currentSession {
                    if let oldProfile = lastTrackedSSID.flatMap({ ProfileManager.shared.getProfile(ssid: $0) }) {
                        ProfileManager.shared.recordUsage(
                            totalUpload: networkMonitor.totalUpload,
                            totalDownload: networkMonitor.totalDownload,
                            profileId: oldProfile.id,
                            sessionId: oldSession.id
                        )
                    }
                    ProfileManager.shared.endSession(oldSession)
                }
                if let pid = profile?.id {
                    ProfileManager.shared.resetCounter(
                        profileId: pid,
                        totalUpload: networkMonitor.totalUpload,
                        totalDownload: networkMonitor.totalDownload
                    )
                    currentSession = ProfileManager.shared.getActiveSession(profileId: pid)
                        ?? ProfileManager.shared.startSession(
                            profileId: pid,
                            latitude: bestLocation.latitude,
                            longitude: bestLocation.longitude,
                            locationSource: bestLocation.source
                        )
                } else {
                    currentSession = nil
                }
                DebugLogger.shared.action("Network", "SSID 변경: \(ssid) (\(lastTrackedSSID ?? "없음") → \(ssid))")
                lastTrackedSSID = ssid
                cacheNeedsInvalidation = true
                NotificationCenter.default.post(name: .init("sessionChanged"), object: nil)
                Task { await ipResolver.refresh(force: true) }
            }

            let todayUsage = cachedUsage ?? (0, 0)
            let totalUsage = cachedTotalUsage ?? cachedUsage ?? (0, 0)
            let todayBytes = todayUsage.upload + todayUsage.download
            todayGB = Double(todayBytes) / 1_000_000_000

            if let quota = totalQuotaGB, quota > 0 {
                if SettingsManager.shared.showTotalColumn {
                    totalStr = formatBytes(todayBytes)
                    let remaining = max(quota - todayGB, 0)
                    let remainLabel = Localized.string("잔여 ", "Remaining ")
                    if remaining >= 1.0 {
                        remainingStr = remainLabel + String(format: "%.1f GB", remaining)
                    } else {
                        remainingStr = remainLabel + String(format: "%.0f MB", remaining * 1000)
                    }
                }

                if SavingModeManager.shared.shouldAutoActivate(used: todayGB, quota: quota) {
                    if !SavingModeManager.shared.isEnabled {
                        SavingModeManager.shared.isEnabled = true
                    }
                }

                checkQuotaThresholds(usedGB: todayGB, quota: quota)
            } else if SettingsManager.shared.showTotalColumn {
                totalStr = formatBytes(totalUsage.upload + totalUsage.download)
                remainingStr = ""
            }
        } else if lastTrackedSSID != nil {
            if let oldSession = currentSession {
                if let oldProfile = lastTrackedSSID.flatMap({ ProfileManager.shared.getProfile(ssid: $0) }) {
                    ProfileManager.shared.recordUsage(
                        totalUpload: networkMonitor.totalUpload,
                        totalDownload: networkMonitor.totalDownload,
                        profileId: oldProfile.id,
                        sessionId: oldSession.id
                    )
                }
                ProfileManager.shared.endSession(oldSession)
            }
            currentSession = nil
            lastTrackedSSID = nil
            Task { await ipResolver.refresh(force: true) }
            lastAutoRegisterSSID = nil
            cacheNeedsInvalidation = true
            NotificationCenter.default.post(name: .init("sessionChanged"), object: nil)
        }

        let quotaRatio: Double
        if let quota = totalQuotaGB, quota > 0 {
            quotaRatio = min(todayGB / quota, 1.0)
        } else if SettingsManager.shared.showTotalColumn, !totalStr.isEmpty {
            quotaRatio = 0
        } else {
            quotaRatio = -1
        }

        let mode = SettingsManager.shared.menuBarMode
        let showSSID = SettingsManager.shared.showSSIDInMenuBar
        var col3Top = totalStr
        var col3Bottom = remainingStr
        if showSSID, let ssid = ssid, !ssid.isEmpty {
            col3Top = ssid
            col3Bottom = ""
        } else if mode == .speedOnly {
            col3Top = ""
            col3Bottom = ""
        }

        menuBarView.update(
            upSpeed: uploadStr, downSpeed: downloadStr,
            col3Top: col3Top, col3Bottom: col3Bottom,
            totalRatio: mode == .speedOnly ? -1 : quotaRatio
        )
        statusItem.length = menuBarView.frame.width
    }

    private nonisolated func authorizeNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendQuotaNotification(used: Double, quota: Double) {
        sendNotification(
            title: Localized.dataQuotaExceeded,
            body: Localized.dataQuotaBody(String(format: "%.1f", used), String(format: "%.1f", quota))
        )
    }

    private func sendThresholdNotification(used: Double, quota: Double, threshold: Double) {
        let pct = Int(threshold * 100)
        sendNotification(
            title: Localized.quotaPercentTitle(pct),
            body: Localized.quotaPercentBody(String(format: "%.1f", used), String(format: "%.1f", quota), pct)
        )
    }

    private nonisolated func sendNotification(title: String, body: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func postQuotaAlert(type: AppNotification.NotificationType, message: String) {
        NotificationManager.shared.add(type: type, message: message)
        NotificationCenter.default.post(name: .init("quotaAlert"), object: nil, userInfo: ["message": message])
    }

    private func togglePopover() {
        if popoverPinned {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // 이전에 남아있던 시트 상태(좀비)를 리셋한 뒤 다시 연다.
            // admin 프롬프트로 resignActive → 팝오버 강제 닫힘 후 클릭이 죽는 문제 방지
            NotificationCenter.default.post(name: .init("popoverWillShow"), object: nil)
            let positioningView: NSView
            let positioningBounds: NSRect
            if let button = statusItem.button {
                positioningView = button
                positioningBounds = button.bounds
            } else {
                positioningView = menuBarView
                positioningBounds = menuBarView.bounds
            }
            popover.show(relativeTo: positioningBounds, of: positioningView, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func togglePin() {
        popoverPinned.toggle()
        popover.behavior = popoverPinned ? .applicationDefined : .transient
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

    private func formatBytes(_ bytes: Int64) -> String {
        let B = Double(bytes)
        if B >= 1_000_000_000 {
            return String(format: "%.1f GB", B / 1_000_000_000)
        } else if B >= 1_000_000 {
            return String(format: "%.1f MB", B / 1_000_000)
        } else if B >= 1_000 {
            return String(format: "%.1f KB", B / 1_000)
        } else {
            return "\(bytes) B"
        }
    }

    private var bestLocation: (latitude: Double?, longitude: Double?, source: String?) {
        if let lat = locationManager.lastLatitude, let lng = locationManager.lastLongitude {
            return (lat, lng, "gps")
        }
        if let ipLoc = ipResolver.resolvedLocation {
            return (ipLoc.latitude, ipLoc.longitude, "ip")
        }
        return (nil, nil, nil)
    }

    private func connectionTypeString(for type: ConnectionType?) -> String? {
        guard let type else { return nil }
        switch type {
        case .iOSPersonalHotspot: return "ios_hotspot"
        case .androidHotspot: return "android_hotspot"
        default: return nil
        }
    }

    private func checkQuotaThresholds(usedGB: Double, quota: Double) {
        let thresholds = [50, 80, 95, 100]
        let pct = min(Int(usedGB / quota * 100), 100)
        guard let profileId = cachedProfile?.id else { return }
        var notified = Self.loadNotifiedThresholds(profileId: profileId)
        var hasNewNotification = false
        for t in thresholds {
            guard pct >= t, !notified.contains(t) else { continue }
            notified.insert(t)
            hasNewNotification = true
            if t == 100 {
                sendQuotaNotification(used: usedGB, quota: quota)
                postQuotaAlert(type: .quotaExceeded, message: Localized.quotaExceeded(String(format: "%.1f", usedGB), String(format: "%.1f", quota)))
                if !SavingModeManager.shared.isEnabled {
                    SavingModeManager.shared.isEnabled = true
                }
            } else {
                sendThresholdNotification(used: usedGB, quota: quota, threshold: Double(t) / 100)
                postQuotaAlert(type: .quotaWarning, message: Localized.quotaReached(t, String(format: "%.1f", usedGB), String(format: "%.1f", quota)))
            }
        }
        if hasNewNotification {
            Self.saveNotifiedThresholds(profileId: profileId, thresholds: notified)
        }
        if pct < thresholds.min() ?? 50, !notified.isEmpty {
            Self.saveNotifiedThresholds(profileId: profileId, thresholds: [])
        }
    }

    private static func loadNotifiedThresholds(profileId: UUID) -> Set<Int> {
        let dict = UserDefaults.standard.dictionary(forKey: Self.notifiedThresholdsKey) as? [String: [Int]] ?? [:]
        return Set(dict[profileId.uuidString] ?? [])
    }

    private static func saveNotifiedThresholds(profileId: UUID, thresholds: Set<Int>) {
        var dict = UserDefaults.standard.dictionary(forKey: Self.notifiedThresholdsKey) as? [String: [Int]] ?? [:]
        dict[profileId.uuidString] = thresholds.sorted()
        UserDefaults.standard.set(dict, forKey: Self.notifiedThresholdsKey)
    }

    private func setupDebugPanelShortcut() {
        guard debugPanelMonitor == nil else { return }
        // LSUIElement 앱은 메뉴바가 없어 NSMenuItem 단축키가 안 먹음 → event monitor 사용
        debugPanelMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.keyCode == 2 {
                Task { @MainActor in
                    DebugPanelController.shared.toggle()
                    DebugLogger.shared.action("UI", "디버그 패널 토글")
                }
                return nil
            }
            return event
        }
    }
}

class MenuBarView: NSView {
    private let upArrow = NSTextField(labelWithString: "▲")
    private let downArrow = NSTextField(labelWithString: "▼")
    private let upSpeed = NSTextField(labelWithString: "")
    private let downSpeed = NSTextField(labelWithString: "")
    private let upTotal = NSTextField(labelWithString: "")
    private let downTotal = NSTextField(labelWithString: "")

    private var currentFontSize: Double = 9

    private var cachedBoldFont: NSFont?
    private var cachedRegFont: NSFont?
    private var cachedRightStyle: NSMutableParagraphStyle?
    private var cachedUpAttr: [NSAttributedString.Key: Any]?
    private var cachedDownAttr: [NSAttributedString.Key: Any]?
    private var cachedSpeedAttr: [NSAttributedString.Key: Any]?
    private var cachedCol2W: CGFloat = 0
    private var cachedCol3W: CGFloat = 0

    private func cacheAttributesIfNeeded(fontSize: Double) -> Bool {
        guard cachedBoldFont == nil || fontSize != currentFontSize else { return false }
        currentFontSize = fontSize

        let boldFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        let regFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let rightStyle = NSMutableParagraphStyle()
        rightStyle.alignment = .right

        cachedBoldFont = boldFont
        cachedRegFont = regFont
        cachedRightStyle = rightStyle
        cachedUpAttr = [.font: boldFont, .foregroundColor: NSColor.systemOrange]
        cachedDownAttr = [.font: boldFont, .foregroundColor: NSColor.systemBlue]
        cachedSpeedAttr = [.font: regFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: rightStyle]

        let col2Sample = NSString(string: "999.0 MB/s").size(withAttributes: [.font: regFont]).width
        cachedCol2W = ceil(col2Sample) + 2
        let col3Sample = Localized.string("잔여 999.9 GB", "Remaining 999.9 GB")
        cachedCol3W = ceil(NSString(string: col3Sample).size(withAttributes: [.font: boldFont]).width)
        return true
    }

    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        [upArrow, downArrow, upSpeed, downSpeed, upTotal, downTotal].forEach { field in
            field.isEditable = false
            field.isSelectable = false
            field.isBordered = false
            field.backgroundColor = .clear
            addSubview(field)
        }
        upSpeed.alignment = .right
        downSpeed.alignment = .right
        upTotal.alignment = .right
        downTotal.alignment = .right
    }

    required init?(coder: NSCoder) { nil }

    func update(upSpeed s1: String, downSpeed s2: String, col3Top t1: String, col3Bottom t2: String, totalRatio: Double = 0) {
        let fontSize = SettingsManager.shared.menuBarFontSize
        let attributesRefreshed = cacheAttributesIfNeeded(fontSize: fontSize)

        guard let boldFont = cachedBoldFont,
              let regFont = cachedRegFont,
              let rightStyle = cachedRightStyle,
              let upAttr = cachedUpAttr,
              let downAttr = cachedDownAttr,
              let speedAttr = cachedSpeedAttr else { return }

        let totalColor = totalRatio < 0 ? NSColor.clear : colorForRatio(totalRatio)
        let totalAttr: [NSAttributedString.Key: Any] = totalRatio < 0 ? [:] : [.font: boldFont, .foregroundColor: totalColor, .paragraphStyle: rightStyle]

        if attributesRefreshed || upArrow.attributedStringValue.string != "▲" {
            upArrow.attributedStringValue = NSAttributedString(string: "▲", attributes: upAttr)
            upArrow.sizeToFit()
        }
        if attributesRefreshed || downArrow.attributedStringValue.string != "▼" {
            downArrow.attributedStringValue = NSAttributedString(string: "▼", attributes: downAttr)
            downArrow.sizeToFit()
        }
        setText(upSpeed, value: s1, attrs: speedAttr)
        setText(downSpeed, value: s2, attrs: speedAttr)
        setText(upTotal, value: t1, attrs: totalAttr)
        setText(downTotal, value: t2, attrs: totalAttr)

        let col3W = totalRatio < 0 ? 0 : cachedCol3W
        let col1X: CGFloat = 1
        let col2X = col1X + upArrow.frame.width + 2
        let col3X = col2X + cachedCol2W + 3
        let w = col3X + col3W + 1

        let h = NSStatusBar.system.thickness
        let lineHeight = max(upArrow.frame.height, upSpeed.frame.height)
        let totalH = lineHeight * 2
        let baseY = (h - totalH) / 2

        upArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY + lineHeight))
        downArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY))
        upSpeed.frame = NSRect(x: col2X, y: baseY + lineHeight, width: cachedCol2W, height: lineHeight)
        downSpeed.frame = NSRect(x: col2X, y: baseY, width: cachedCol2W, height: lineHeight)
        upTotal.frame = NSRect(x: col3X, y: baseY + lineHeight, width: col3W, height: lineHeight)
        downTotal.frame = NSRect(x: col3X, y: baseY, width: col3W, height: lineHeight)

        frame.size = NSSize(width: w, height: h)
    }

    private func setText(_ field: NSTextField, value: String, attrs: [NSAttributedString.Key: Any]) {
        if field.attributedStringValue.string != value {
            field.attributedStringValue = NSAttributedString(string: value, attributes: attrs)
            field.sizeToFit()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    private func colorForRatio(_ ratio: Double) -> NSColor {
        let greenBoundary = SavingModeManager.shared.greenThreshold
        let orangeBoundary = SavingModeManager.shared.orangeThreshold
        if ratio < greenBoundary {
            return .systemGreen
        } else if ratio < orangeBoundary {
            return .systemOrange
        } else {
            return .systemRed
        }
    }

}
