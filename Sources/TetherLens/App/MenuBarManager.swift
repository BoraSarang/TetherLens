import AppKit
import SwiftUI
import UserNotifications

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
class MenuBarManager: NSObject, NSPopoverDelegate, @unchecked Sendable {
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

        // PingMonitor가 OS 레벨 연결 상태(NWPathMonitor)와 교차 검증하도록 주입 (v0.31)
        pingMonitor.hotspotDetector = hotspotDetector

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
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePowerStateChanged),
            name: .init("powerStateChanged"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleBlockedAppsChanged),
            name: .init("blockedAppsChanged"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleTogglePopover),
            name: .init("togglePopover"), object: nil
        )
    }

    /// ⌘⇧P 메뉴/단축키에서 팝오버를 연다 (v0.30).
    @objc private func handleTogglePopover() {
        togglePopover()
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
        TrafficMonitor.shared.suspend()
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
        TrafficMonitor.shared.resume()
        locationManager.startUpdating()
        setupTimers()
        refreshCache()
        updateMenuBarText()
        NotificationCenter.default.post(name: connectionChanged, object: nil)
    }

    /// 저전력 모드 토글 — TrafficMonitor 강제 중지/재개 + 메뉴바 갱신 주기 확대.
    @objc private func handlePowerStateChanged() {
        guard isMonitoring else { return }
        let lowPower = SavingModeManager.shared.isLowPowerMode
        DebugLogger.shared.system("Power", "저전력 모드 \(lowPower ? "ON" : "OFF")")
        TrafficMonitor.shared.setLowPower(lowPower)
        // 메뉴바 갱신 주기 재계산 (저전력 시 확대)
        timer?.invalidate()
        timer = nil
        timer = scheduleTimer(effectiveMenuBarRefreshInterval) { [weak self] in
            self?.updateMenuBarText()
        }
        updateMenuBarText()
    }

    /// 차단 목록 변경 — 차단 감지가 필요하면 TrafficMonitor를 상시 유지.
    @objc private func handleBlockedAppsChanged() {
        guard isMonitoring else { return }
        if AppBlockManager.shared.blockedApps.isEmpty {
            TrafficMonitor.shared.release(reason: .appBlock)
        } else {
            TrafficMonitor.shared.acquire(reason: .appBlock)
        }
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
        // TrafficMonitor는 참조 기반 지연 시작이라 간격 변경은 다음 refresh에 자동 반영된다.
        TrafficMonitor.shared.resume()
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
        let floatingLabel = FloatingWindowController.shared.isVisible ? Localized.floatingWindowHide : Localized.floatingWindowShow
        menu.addItem(moreMenuItem(floatingLabel) {
            FloatingWindowController.shared.toggle()
        })
        menu.addItem(.separator())
        menu.addItem(moreMenuItem(Localized.networkDiagnostics) {
            DiagnosticsWindowController.shared.show()
        })
        menu.addItem(moreMenuItem(Localized.manageProfiles) { [weak self] in
            self?.openPopoverAndTrigger("profileManager")
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
        // 팝오버 표시/닫힘을 OS 레벨에서 정확히 감지해 TrafficMonitor를 제어한다.
        // (SwiftUI onAppear/onDisappear는 transient 닫힘에서 미호출되는 경우가 있어 사용하지 않는다)
        popover.delegate = self
    }

    // MARK: - NSPopoverDelegate
    // 팝오버가 표시되는 동안에만 nettop 기반 앱 트래픽을 수집 (에너지 최적화 — v0.28.1 이전)
    // 참고: 외부 클릭/ESC/핀 해제 등 모든 닫힘 경로에서 popoverDidClose가 호출된다.
    func popoverDidShow(_ notification: Notification) {
        TrafficMonitor.shared.acquire(reason: .popover)
    }

    func popoverDidClose(_ notification: Notification) {
        TrafficMonitor.shared.release(reason: .popover)
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
        // 차단된 앱이 없으면 상시 nettop 구동이 불필요 — 차단 감지가 있을 때만 유지.
        if !AppBlockManager.shared.blockedApps.isEmpty {
            TrafficMonitor.shared.acquire(reason: .appBlock)
        }

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

        ipRefreshTimer = scheduleTimer(3600) { [weak self] in
            Task { [weak self] in
                guard let self else { return }
                if SavingModeManager.shared.isLowPowerMode {
                    // 저전력 중 IP 갱신 스킵은 정상 동작 — info 레벨로 노이즈 최소화 (v0.28.2)
                    DebugLogger.shared.info("Power", "저전력 모드 - IP 갱신 건너뜀")
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

        timer = scheduleTimer(effectiveMenuBarRefreshInterval) { [weak self] in
            self?.updateMenuBarText()
        }
    }

    /// 저전력 모드이면 메뉴바 갱신 주기를 최소 5초로 확대해 에너지를 절약한다.
    private var effectiveMenuBarRefreshInterval: Double {
        if SavingModeManager.shared.isLowPowerMode {
            return max(SettingsManager.shared.menuBarRefreshInterval, 5.0)
        }
        return SettingsManager.shared.menuBarRefreshInterval
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
        TrafficMonitor.shared.resetAllUsage()
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
        if ssid == nil, let prev = lastAutoRegisterSSID {
            AutomationManager.shared.evaluate(ssid: prev, connected: false)
        }
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
                AutomationManager.shared.evaluate(ssid: ssid, connected: true)
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

        // col3은 할당량 설정 여부에 따라 자동 전환한다 (v0.31):
        // - 할당량 설정 + 사용량 열 ON  → 사용량(top) / 잔여(bottom)  [현행 유지]
        // - 그 외(할당량 미설정 등)     → RSSI(top) / 지연시간(bottom)
        let quotaConfigured = (totalQuotaGB ?? 0) > 0
        let rssi = hotspotDetector.currentConnection?.rssi
        let latency = pingMonitor.primaryLatency

        var col3Top: String
        var col3Bottom: String
        var col3IsUsage: Bool
        var col3Ratio: Double
        var col3IsLatency: Bool
        var col3Hidden: Bool
        var col3TopColor: NSColor?
        var col3BottomColor: NSColor?

        if quotaConfigured, SettingsManager.shared.showTotalColumn {
            col3Top = totalStr
            col3Bottom = remainingStr
            col3IsUsage = true
            col3Ratio = quotaRatio
            col3IsLatency = false
            let usageColor = Self.usageRatioNSColor(quotaRatio)
            col3TopColor = usageColor
            col3BottomColor = usageColor
            col3Hidden = false
        } else {
            let showRSSI = SettingsManager.shared.showRSSI
            let showLatency = SettingsManager.shared.showLatency
            col3Top = showRSSI ? Self.rssiString(rssi) : ""
            col3Bottom = showLatency ? Self.latencyString(latency) : ""
            col3IsUsage = false
            col3Ratio = -1
            col3IsLatency = showRSSI || showLatency
            col3TopColor = showRSSI ? Self.rssiNSColor(rssi) : nil
            col3BottomColor = showLatency ? Self.latencyNSColor(latency) : nil
            col3Hidden = !(showRSSI || showLatency)
        }

        menuBarView.update(
            upSpeed: uploadStr, downSpeed: downloadStr,
            col3Top: col3Top, col3Bottom: col3Bottom,
            col3Hidden: col3Hidden,
            col3TopColor: col3TopColor, col3BottomColor: col3BottomColor
        )
        statusItem.length = menuBarView.frame.width
        // 메뉴바 호버 툴팁 — 클릭 없이 전체 상태 확인 (Osaurus 상태 툴팁 패턴)
        let tipName = hotspotDetector.currentConnection?.ssid ?? "TetherLens"
        var tip = "\(tipName) · ▲\(uploadStr) ▼\(downloadStr)"
        if quotaRatio >= 0 {
            tip += " · QoS \(Int(quotaRatio * 100))%"
        }
        menuBarView.toolTip = tip
        // 플로팅 창에 메뉴바와 동일한 표시 내용을 공급 (v0.31) — 설정·tick 경로에서 항상 발행되어 동기화
        NotificationCenter.default.post(
            name: .init("floatingContentChanged"), object: nil,
            userInfo: [
                "up": uploadStr, "down": downloadStr,
                "col3Top": col3Top, "col3Bottom": col3Bottom,
                "ratio": col3Ratio,
                "col3IsUsage": col3IsUsage,
                // RSSI/지연 표시 시 뷰가 색상을 그릴 수 있도록 원시값을 함께 전달
                "rssi": rssi.map(String.init) ?? "",
                "latencyMS": latency.map { String(Int($0 * 1000)) } ?? "",
                "col3IsLatency": col3IsLatency,
                "reachable": pingMonitor.isReachable
            ]
        )
    }

    // MARK: - RSSI / 지연시간 형식·색상 (할당량 미설정 시 col3)

    nonisolated static func rssiString(_ rssi: Int?) -> String {
        guard let rssi else { return "--" }
        return "\(rssi) dBm"
    }

    nonisolated static func latencyString(_ rtt: TimeInterval?) -> String {
        guard let rtt else { return "--" }
        return "\(Int(rtt * 1000)) ms"
    }

    /// RSSI 신호 색상: ≥-50 양호(초록) / -67~-50 보통(주황) / <-67 약함(빨강)
    nonisolated static func rssiColor(_ rssi: Int?) -> Color {
        guard let rssi else { return TLPalette.textSecondary }
        if rssi >= -50 { return TLPalette.success }
        if rssi >= -67 { return TLPalette.upload }
        return TLPalette.danger
    }

    /// 지연 색상: <50ms 양호(초록) / <150ms 보통(주황) / ≥150ms 불량(빨강)
    nonisolated static func latencyColor(_ rtt: TimeInterval?) -> Color {
        guard let rtt else { return TLPalette.textSecondary }
        if rtt < 0.05 { return TLPalette.success }
        if rtt < 0.15 { return TLPalette.upload }
        return TLPalette.danger
    }

    // NSView(메뉴바)용 NSColor 변환 — TLPalette 시맨틱 색과 동일한 P3 값 사용
    nonisolated static func rssiNSColor(_ rssi: Int?) -> NSColor {
        guard let rssi else { return .secondaryLabelColor }
        if rssi >= -50 { return NSColor(red: 0.149, green: 0.651, blue: 0.318, alpha: 1) }
        if rssi >= -67 { return NSColor(red: 0.902, green: 0.514, blue: 0.227, alpha: 1) }
        return NSColor(red: 0.937, green: 0.255, blue: 0.263, alpha: 1)
    }

    nonisolated static func latencyNSColor(_ rtt: TimeInterval?) -> NSColor {
        guard let rtt else { return .secondaryLabelColor }
        if rtt < 0.05 { return NSColor(red: 0.149, green: 0.651, blue: 0.318, alpha: 1) }
        if rtt < 0.15 { return NSColor(red: 0.902, green: 0.514, blue: 0.227, alpha: 1) }
        return NSColor(red: 0.937, green: 0.255, blue: 0.263, alpha: 1)
    }

    nonisolated static func usageRatioNSColor(_ ratio: Double) -> NSColor {
        let green = SavingModeManager.shared.greenThreshold
        let orange = SavingModeManager.shared.orangeThreshold
        if ratio < green { return NSColor(red: 0.149, green: 0.651, blue: 0.318, alpha: 1) }
        if ratio < orange { return NSColor(red: 0.902, green: 0.514, blue: 0.227, alpha: 1) }
        return NSColor(red: 0.937, green: 0.255, blue: 0.263, alpha: 1)
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
    // SF Symbol 템플릿 아이콘 (다크/라이트/접근성에서 OS가 자동 착색)
    private let upIcon = NSImageView()
    private let downIcon = NSImageView()
    private let upSpeed = NSTextField(labelWithString: "")
    private let downSpeed = NSTextField(labelWithString: "")
    private let upTotal = NSTextField(labelWithString: "")
    private let downTotal = NSTextField(labelWithString: "")

    private var currentFontSize: Double = 9
    private var cachedIconW: CGFloat = 11

    private var cachedBoldFont: NSFont?
    private var cachedRegFont: NSFont?
    private var cachedRightStyle: NSMutableParagraphStyle?
    private var cachedUpAttr: [NSAttributedString.Key: Any]?
    private var cachedDownAttr: [NSAttributedString.Key: Any]?
    private var cachedSpeedAttr: [NSAttributedString.Key: Any]?
    private var cachedCol2W: CGFloat = 0
    private var cachedCol3W: CGFloat = 0

    private func makeSymbol(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: currentFontSize + 1, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: name)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

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

        upIcon.image = makeSymbol("arrow.up")
        downIcon.image = makeSymbol("arrow.down")
        cachedIconW = ceil(max(upIcon.image?.size.width ?? 0, downIcon.image?.size.width ?? 0)) + 2

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
        [upIcon, downIcon].forEach { icon in
            icon.imageScaling = .scaleProportionallyDown
            addSubview(icon)
        }
        [upSpeed, downSpeed, upTotal, downTotal].forEach { field in
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

    func update(upSpeed s1: String, downSpeed s2: String, col3Top t1: String, col3Bottom t2: String,
                col3Hidden: Bool = false, col3TopColor: NSColor? = nil, col3BottomColor: NSColor? = nil) {
        let fontSize = SettingsManager.shared.menuBarFontSize
        let attributesRefreshed = cacheAttributesIfNeeded(fontSize: fontSize)

        guard let boldFont = cachedBoldFont,
              let regFont = cachedRegFont,
              let rightStyle = cachedRightStyle,
              let upAttr = cachedUpAttr,
              let downAttr = cachedDownAttr,
              let speedAttr = cachedSpeedAttr else { return }

        // col3 두 줄에 각각 색상을 적용. 색상이 nil이면 기본(라벨색).
        let topAttr: [NSAttributedString.Key: Any] = [.font: boldFont, .foregroundColor: col3TopColor ?? .labelColor, .paragraphStyle: rightStyle]
        let bottomAttr: [NSAttributedString.Key: Any] = [.font: boldFont, .foregroundColor: col3BottomColor ?? .labelColor, .paragraphStyle: rightStyle]

        _ = upAttr
        _ = downAttr
        _ = attributesRefreshed
        setText(upSpeed, value: s1, attrs: speedAttr)
        setText(downSpeed, value: s2, attrs: speedAttr)
        setText(upTotal, value: t1, attrs: topAttr)
        setText(downTotal, value: t2, attrs: bottomAttr)

        // col3 폭: 실제 두 줄 텍스트 중 최대 폭으로 동적 계산 (오른쪽 정렬 유지).
        // 숨김(col3Hidden)이거나 두 줄 다 비어 있으면 0.
        let col3W: CGFloat
        if col3Hidden {
            col3W = 0
        } else {
            let topW = NSString(string: t1).size(withAttributes: topAttr).width
            let bottomW = NSString(string: t2).size(withAttributes: bottomAttr).width
            col3W = ceil(max(topW, bottomW)) + 2
        }
        let col1X: CGFloat = 1
        let col2X = col1X + cachedIconW + 2
        let col3X = col2X + cachedCol2W + 3
        let w = col3X + col3W + 1

        let h = NSStatusBar.system.thickness
        let lineHeight = max(upIcon.image?.size.height ?? fontSize + 3, upSpeed.frame.height)
        let totalH = lineHeight * 2
        let baseY = (h - totalH) / 2
        let iconH = lineHeight

        upIcon.frame = NSRect(x: col1X, y: baseY + lineHeight, width: cachedIconW, height: iconH)
        downIcon.frame = NSRect(x: col1X, y: baseY, width: cachedIconW, height: iconH)
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

}
