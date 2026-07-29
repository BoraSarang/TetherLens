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
    private var lastQuotaNotified: Bool = false

    private let notiDelegate = NotificationDelegate()

    private var lastTrackedSSID: String?
    private var currentSession: Session?

    private var cachedProfile: Profile?
    private var cachedUsage: (upload: Int64, download: Int64)?
    private var cachedTotalUsage: (upload: Int64, download: Int64)?
    private var cacheNeedsInvalidation = false

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
        _ = ProfileManager.shared.autoRegisterIfNeeded(ssid: ssid)
        updateMenuBarText()
        NotificationCenter.default.post(name: connectionChanged, object: nil)
    }

    @objc private func handleAppTermination() {
        ProfileManager.shared.endAllActiveSessions()
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
        statusItem.view = menuBarView
        updateMenuBarText()
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
        authorizeNotifications()

        setupDebugPanelShortcut()
        DebugLogger.shared.system("App", "앱 시작됨")

        networkMonitor.start()
        hotspotDetector.start()
        pingMonitor.start()
        TrafficMonitor.shared.start()

        // 네트워크 연결 확인 후 1회 IP 조회
        Task {
            for _ in 0..<15 {
                if hotspotDetector.isNetworkAvailable { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await ipResolver.refresh()
        }

        ProfileManager.shared.cleanupOldLogs()
        ProfileManager.shared.cleanupAppTrafficLogs()
        ProfileManager.shared.endAllActiveSessions()
        NotificationCenter.default.post(name: .init("sessionChanged"), object: nil)

        refreshCache()

        if let ssid = hotspotDetector.currentConnection?.ssid,
           let profile = cachedProfile {
            currentSession = ProfileManager.shared.getActiveSession(profileId: profile.id)
            if currentSession == nil {
                currentSession = ProfileManager.shared.startSession(profileId: profile.id)
            }
            lastTrackedSSID = ssid
        }

        recordTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.recordCurrentUsage()
            }
        }

        ipRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.ipResolver.refresh() }
        }

        cacheTimer = Timer.scheduledTimer(withTimeInterval: SettingsManager.shared.cacheRefreshInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshCache()
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: SettingsManager.shared.menuBarRefreshInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarText()
            }
        }
    }

    func stopMonitoring() {
        DebugLogger.shared.system("App", "모니터링 중지")
        timer?.invalidate()
        timer = nil
        cacheTimer?.invalidate()
        cacheTimer = nil
        recordTimer?.invalidate()
        recordTimer = nil
        ipRefreshTimer?.invalidate()
        ipRefreshTimer = nil
        networkMonitor.stop()
        hotspotDetector.stop()
        pingMonitor.stop()
        TrafficMonitor.shared.stop()
    }

    private func recordCurrentUsage() {
        guard let ssid = hotspotDetector.currentConnection?.ssid,
              let profile = ProfileManager.shared.getProfile(ssid: ssid) else { return }
        ProfileManager.shared.recordUsage(
            totalUpload: networkMonitor.totalUpload,
            totalDownload: networkMonitor.totalDownload,
            profileId: profile.id
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
            if cachedProfile?.quotaGB == nil {
                cachedTotalUsage = ProfileManager.shared.getTotalUsage(profileId: pid)
            } else {
                cachedTotalUsage = nil
            }
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

        if let ssid = ssid, !ssid.isEmpty {
            if ssid != lastAutoRegisterSSID {
                lastAutoRegisterSSID = ssid
                _ = ProfileManager.shared.autoRegisterIfNeeded(ssid: ssid)
                cacheNeedsInvalidation = true
            }

            let profile = cachedProfile ?? ProfileManager.shared.getProfile(ssid: ssid)
            totalQuotaGB = profile?.quotaGB

            if ssid != lastTrackedSSID {
                if let oldSession = currentSession {
                    ProfileManager.shared.endSession(oldSession)
                }
                if let pid = profile?.id {
                    currentSession = ProfileManager.shared.startSession(profileId: pid)
                } else {
                    currentSession = nil
                }
                DebugLogger.shared.action("Network", "SSID 변경: \(ssid) (\(lastTrackedSSID ?? "없음") → \(ssid))")
                lastTrackedSSID = ssid
                cacheNeedsInvalidation = true
                NotificationCenter.default.post(name: .init("sessionChanged"), object: nil)
                Task { await ipResolver.refresh(force: true) }
            }

            let usage = cachedUsage ?? (0, 0)
            let totalBytes = usage.upload + usage.download
            let totalGB = Double(totalBytes) / 1_000_000_000

            if let quota = totalQuotaGB, quota > 0 {
                if SettingsManager.shared.showTotalColumn {
                    totalStr = formatBytes(totalBytes)
                    let remaining = quota - totalGB
                    if remaining >= 1.0 {
                        remainingStr = "잔여 " + String(format: "%.1f GB", remaining)
                    } else {
                        remainingStr = "잔여 " + String(format: "%.0f MB", remaining * 1000)
                    }
                }

                if SavingModeManager.shared.shouldAutoActivate(used: totalGB, quota: quota) {
                    if !SavingModeManager.shared.isEnabled {
                        SavingModeManager.shared.isEnabled = true
                    }
                }
            } else if SettingsManager.shared.showTotalColumn {
                totalStr = formatBytes(totalBytes)
                let totalAll = cachedTotalUsage ?? (0, 0)
                remainingStr = formatBytes(totalAll.upload + totalAll.download)
            }
        } else if lastTrackedSSID != nil {
            if let oldSession = currentSession {
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
        if SettingsManager.shared.showTotalColumn, let quota = totalQuotaGB, quota > 0 {
            let usage = cachedUsage ?? (0, 0)
            let totalGB = Double(usage.upload + usage.download) / 1_000_000_000
            quotaRatio = min(totalGB / quota, 1.0)
        } else if SettingsManager.shared.showTotalColumn, !totalStr.isEmpty {
            quotaRatio = 0
        } else {
            quotaRatio = -1
        }

        menuBarView.update(
            upSpeed: uploadStr, downSpeed: downloadStr,
            col3Top: totalStr, col3Bottom: remainingStr,
            totalRatio: quotaRatio
        )
        statusItem.length = menuBarView.frame.width

        if let quota = totalQuotaGB, quota > 0 {
            let usage = cachedUsage ?? (0, 0)
            let todayGB = Double(usage.upload + usage.download) / 1_000_000_000
            let threshold = SettingsManager.shared.quotaWarningThreshold
            if threshold < 1.0, todayGB >= quota * threshold {
                if !lastQuotaNotified {
                    lastQuotaNotified = true
                    sendThresholdNotification(used: todayGB, quota: quota, threshold: threshold)
                    postQuotaAlert(type: .quotaWarning, message: "할당량 \(Int(threshold * 100))% 도달 — \(String(format: "%.1f", todayGB))GB / \(String(format: "%.1f", quota))GB")
                }
            } else if threshold >= 1.0, todayGB >= quota {
                if !lastQuotaNotified {
                    lastQuotaNotified = true
                    sendQuotaNotification(used: todayGB, quota: quota)
                    postQuotaAlert(type: .quotaExceeded, message: "할당량 초과 — \(String(format: "%.1f", todayGB))GB / \(String(format: "%.1f", quota))GB")
                }
            } else {
                lastQuotaNotified = false
            }
        }
    }

    private nonisolated func authorizeNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendQuotaNotification(used: Double, quota: Double) {
        sendNotification(
            title: "데이터 할당량 초과",
            body: "\(String(format: "%.1f", used))GB / \(String(format: "%.1f", quota))GB 사용"
        )
    }

    private func sendThresholdNotification(used: Double, quota: Double, threshold: Double) {
        let pct = Int(threshold * 100)
        sendNotification(
            title: "데이터 할당량 \(pct)% 도달",
            body: "\(String(format: "%.1f", used))GB / \(String(format: "%.1f", quota))GB 사용 (\(pct)%)"
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

    private func setupDebugPanelShortcut() {
        // LSUIElement 앱은 메뉴바가 없어 NSMenuItem 단축키가 안 먹음 → event monitor 사용
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.keyCode == 2 {
                self?.toggleDebugPanel()
                return nil
            }
            return event
        }
    }

    private func toggleDebugPanel() {
        // popover가 debug panel 위에 뜨지 않도록 먼저 닫음
        popover.performClose(nil)
        DebugPanelController.shared.toggle()
        DebugLogger.shared.action("UI", "디버그 패널 토글 (visible=\(DebugPanelController.shared.isVisible))")
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

    private var col2FixedW: CGFloat {
        let f = NSFont.monospacedDigitSystemFont(ofSize: currentFontSize, weight: .regular)
        return ceil(NSString(string: "999.0 MB/s").size(withAttributes: [.font: f]).width) + 2
    }
    private var col3FixedW: CGFloat {
        let f = NSFont.monospacedDigitSystemFont(ofSize: currentFontSize, weight: .bold)
        let base = NSString(string: "잔여 999.9 GB").size(withAttributes: [.font: f]).width
        return ceil(base)
    }

    var onClick: (() -> Void)?

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
        currentFontSize = fontSize

        let boldFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        let regFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let rightStyle = NSMutableParagraphStyle()
        rightStyle.alignment = .right

        let upAttr: [NSAttributedString.Key: Any] = [.font: boldFont, .foregroundColor: NSColor.systemOrange]
        let downAttr: [NSAttributedString.Key: Any] = [.font: boldFont, .foregroundColor: NSColor.systemBlue]
        let speedAttr: [NSAttributedString.Key: Any] = [.font: regFont, .foregroundColor: NSColor.white, .paragraphStyle: rightStyle]

        let totalColor = totalRatio < 0 ? NSColor.clear : colorForRatio(totalRatio)
        let totalAttr: [NSAttributedString.Key: Any] = totalRatio < 0 ? [:] : [.font: boldFont, .foregroundColor: totalColor, .paragraphStyle: rightStyle]

        upArrow.attributedStringValue = NSAttributedString(string: "▲", attributes: upAttr)
        downArrow.attributedStringValue = NSAttributedString(string: "▼", attributes: downAttr)
        upArrow.sizeToFit()
        downArrow.sizeToFit()
        setText(upSpeed, value: s1, attrs: speedAttr)
        setText(downSpeed, value: s2, attrs: speedAttr)
        setText(upTotal, value: t1, attrs: totalAttr)
        setText(downTotal, value: t2, attrs: totalAttr)

        let col3W = totalRatio < 0 ? 0 : col3FixedW
        let col1X: CGFloat = 1
        let col2X = col1X + upArrow.frame.width + 2
        let col3X = col2X + col2FixedW + 3
        let w = col3X + col3W + 1

        let h = NSStatusBar.system.thickness
        let lineHeight = max(upArrow.frame.height, upSpeed.frame.height)
        let totalH = lineHeight * 2
        let baseY = (h - totalH) / 2

        upArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY + lineHeight))
        downArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY))
        upSpeed.frame = NSRect(x: col2X, y: baseY + lineHeight, width: col2FixedW, height: lineHeight)
        downSpeed.frame = NSRect(x: col2X, y: baseY, width: col2FixedW, height: lineHeight)
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

    private func colorForRatio(_ ratio: Double) -> NSColor {
        let greenBoundary = SavingModeManager.shared.isEnabled ? 0.4 : 0.6
        let orangeBoundary = SavingModeManager.shared.isEnabled ? 0.65 : 0.85
        if ratio < greenBoundary {
            return .systemGreen
        } else if ratio < orangeBoundary {
            return .systemOrange
        } else {
            return .systemRed
        }
    }

}
