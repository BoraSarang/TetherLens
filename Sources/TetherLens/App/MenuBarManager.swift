import AppKit
import SwiftUI
import UserNotifications

@MainActor
class MenuBarManager: NSObject, @unchecked Sendable {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var timer: Timer?

    private let networkMonitor = NetworkMonitor()
    private let hotspotDetector = HotspotDetector()
    private let pingMonitor = PingMonitor()
    private let ipResolver = IPResolver()
    private let locationManager: LocationManager

    private let menuBarView = MenuBarView()

    private let connectionChanged = Notification.Name("connectionChanged")
    private var lastAutoRegisterSSID: String?
    private var recordTimer: Timer?
    private var lastQuotaNotified: Bool = false

    private var lastTrackedSSID: String?
    private var currentSession: Session?

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

        setupMenuBar()
        setupPopover()
        setupLocationCallback()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCurrentProfileDeleted),
            name: .init("currentProfileDeleted"), object: nil
        )
    }

    @objc private func handleCurrentProfileDeleted() {
        guard let ssid = hotspotDetector.currentConnection?.ssid, !ssid.isEmpty else { return }
        lastAutoRegisterSSID = nil
        _ = ProfileManager.shared.autoRegisterIfNeeded(ssid: ssid)
        updateMenuBarText()
        NotificationCenter.default.post(name: connectionChanged, object: nil)
    }

    private func setupLocationCallback() {
        locationManager.onAuthorizationChange = { [weak self] authorized in
            guard let self else { return }
            hotspotDetector.refreshNow()
            updateMenuBarText()
            Task { await self.ipResolver.refresh() }
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
            locationManager: locationManager
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    func startMonitoring() {
        networkMonitor.start()
        hotspotDetector.start()
        pingMonitor.start()

        Task { await ipResolver.refresh() }

        ProfileManager.shared.cleanupOldLogs()

        if let ssid = hotspotDetector.currentConnection?.ssid,
           let profile = ProfileManager.shared.getProfile(ssid: ssid) {
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

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarText()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        recordTimer?.invalidate()
        recordTimer = nil
        networkMonitor.stop()
        hotspotDetector.stop()
        pingMonitor.stop()
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

    private func updateMenuBarText() {
        let upload = networkMonitor.currentUploadSpeed
        let download = networkMonitor.currentDownloadSpeed
        let uploadStr = formatSpeed(upload)
        let downloadStr = formatSpeed(download)

        let ssid = hotspotDetector.currentConnection?.ssid
        var totalQuotaGB: Double?
        var totalStr = ""
        var remainingStr = ""

        if let ssid = ssid, !ssid.isEmpty {
            if ssid != lastAutoRegisterSSID {
                lastAutoRegisterSSID = ssid
                _ = ProfileManager.shared.autoRegisterIfNeeded(ssid: ssid)
            }
            let profile = ProfileManager.shared.getProfile(ssid: ssid)
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
                lastTrackedSSID = ssid
                NotificationCenter.default.post(name: .init("sessionChanged"), object: nil)
            }

            let usage = profile.map { ProfileManager.shared.getTodayUsage(profileId: $0.id) } ?? (0, 0)
            let totalBytes = usage.upload + usage.download
            let totalGB = Double(totalBytes) / 1_000_000_000

            if let quota = totalQuotaGB, quota > 0 {
                if SettingsManager.shared.showTotalColumn {
                    totalStr = formatBytes(totalBytes)
                    let remaining = quota - totalGB
                    if remaining >= 1.0 {
                        remainingStr = "잔여 " + String(format: "%.1fGB", remaining)
                    } else {
                        remainingStr = "잔여 " + String(format: "%.0fMB", remaining * 1000)
                    }
                }

                if SavingModeManager.shared.shouldAutoActivate(used: totalGB, quota: quota) {
                    if !SavingModeManager.shared.isEnabled {
                        SavingModeManager.shared.isEnabled = true
                    }
                }
            } else if SettingsManager.shared.showTotalColumn {
                totalStr = formatBytes(totalBytes)
                let totalUsage = profile.map { ProfileManager.shared.getTotalUsage(profileId: $0.id) } ?? (0, 0)
                let totalAllBytes = totalUsage.upload + totalUsage.download
                remainingStr = formatBytes(totalAllBytes)
            }
        }

        let quotaRatio: Double
        if SettingsManager.shared.showTotalColumn, let quota = totalQuotaGB, quota > 0 {
            let totalGB = ssid.flatMap { ProfileManager.shared.getProfile(ssid: $0) }.map { p in
                let u = ProfileManager.shared.getTodayUsage(profileId: p.id)
                return Double(u.upload + u.download) / 1_000_000_000
            } ?? 0
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
            let todayGB = ssid.flatMap { ProfileManager.shared.getProfile(ssid: $0) }.map { p in
                let u = ProfileManager.shared.getTodayUsage(profileId: p.id)
                return Double(u.upload + u.download) / 1_000_000_000
            } ?? 0
            if todayGB >= quota {
                if !lastQuotaNotified {
                    lastQuotaNotified = true
                    sendQuotaNotification(used: todayGB, quota: quota)
                }
            } else {
                lastQuotaNotified = false
            }
        }
    }

    private func sendQuotaNotification(used: Double, quota: Double) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "데이터 할당량 초과"
            content.body = "\(String(format: "%.1f", used))GB / \(String(format: "%.1f", quota))GB 사용"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "quota-exceeded-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: menuBarView.bounds, of: menuBarView, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
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
}

class MenuBarView: NSView {
    private let upArrow = NSTextField(labelWithString: "▲")
    private let downArrow = NSTextField(labelWithString: "▼")
    private let upSpeed = NSTextField(labelWithString: "")
    private let downSpeed = NSTextField(labelWithString: "")
    private let upTotal = NSTextField(labelWithString: "")
    private let downTotal = NSTextField(labelWithString: "")

    private static let col2FixedW: CGFloat = {
        let f = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        return ceil(NSString(string: "999.0 MB/s").size(withAttributes: [.font: f]).width) + 2
    }()
    private static let col3FixedW: CGFloat = {
        let f = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        let base = NSString(string: "잔여 999.9 GB").size(withAttributes: [.font: f]).width
        return ceil(base) + 5
    }()

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
        let bold9 = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        let reg9 = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        let rightStyle = NSMutableParagraphStyle()
        rightStyle.alignment = .right

        let totalColor = totalRatio < 0 ? NSColor.clear : colorForRatio(totalRatio)

        upArrow.attributedStringValue = NSAttributedString(string: "▲", attributes: [.font: bold9, .foregroundColor: NSColor.systemOrange])
        downArrow.attributedStringValue = NSAttributedString(string: "▼", attributes: [.font: bold9, .foregroundColor: NSColor.systemBlue])
        upSpeed.attributedStringValue = NSAttributedString(string: s1, attributes: [.font: reg9, .foregroundColor: NSColor.white, .paragraphStyle: rightStyle])
        downSpeed.attributedStringValue = NSAttributedString(string: s2, attributes: [.font: reg9, .foregroundColor: NSColor.white, .paragraphStyle: rightStyle])
        upTotal.attributedStringValue = totalRatio < 0
            ? NSAttributedString(string: "", attributes: [:])
            : NSAttributedString(string: t1, attributes: [.font: bold9, .foregroundColor: totalColor, .paragraphStyle: rightStyle])
        downTotal.attributedStringValue = totalRatio < 0
            ? NSAttributedString(string: "", attributes: [:])
            : NSAttributedString(string: t2, attributes: [.font: bold9, .foregroundColor: totalColor, .paragraphStyle: rightStyle])

        [upArrow, downArrow, upSpeed, downSpeed, upTotal, downTotal].forEach { $0.sizeToFit() }

        let col3W = totalRatio < 0 ? 0 : Self.col3FixedW
        let col1X: CGFloat = 1
        let col2X = col1X + upArrow.frame.width + 2
        let col3X = col2X + Self.col2FixedW + 3
        let w = col3X + col3W + 1

        let h = NSStatusBar.system.thickness
        let lineHeight = max(upArrow.frame.height, upSpeed.frame.height)
        let totalH = lineHeight * 2
        let baseY = (h - totalH) / 2

        upArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY + lineHeight))
        downArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY))
        upSpeed.frame = NSRect(x: col2X, y: baseY + lineHeight, width: Self.col2FixedW, height: lineHeight)
        downSpeed.frame = NSRect(x: col2X, y: baseY, width: Self.col2FixedW, height: lineHeight)
        upTotal.frame = NSRect(x: col3X, y: baseY + lineHeight, width: col3W, height: lineHeight)
        downTotal.frame = NSRect(x: col3X, y: baseY, width: col3W, height: lineHeight)

        frame.size = NSSize(width: w, height: h)
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
