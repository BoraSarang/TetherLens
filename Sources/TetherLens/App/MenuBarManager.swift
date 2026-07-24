import AppKit
import SwiftUI

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

    let connectionChanged = Notification.Name("connectionChanged")

    init(locationManager: LocationManager) {
        self.locationManager = locationManager

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient

        super.init()

        setupMenuBar()
        setupPopover()
        setupLocationCallback()
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

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarText()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        networkMonitor.stop()
        hotspotDetector.stop()
        pingMonitor.stop()
    }

    private func updateMenuBarText() {
        let upload = networkMonitor.currentUploadSpeed
        let download = networkMonitor.currentDownloadSpeed
        let totalUpload = networkMonitor.totalUpload
        let totalDownload = networkMonitor.totalDownload

        let uploadStr = formatSpeed(upload)
        let downloadStr = formatSpeed(download)
        let upTotalStr = formatBytes(totalUpload)
        let dnTotalStr = formatBytes(totalDownload)

        let totalUsedGB = 2.7
        let totalQuotaGB = 3.0
        let quotaRatio = min(totalUsedGB / totalQuotaGB, 1.0)

        menuBarView.update(
            upSpeed: uploadStr, downSpeed: downloadStr,
            upTotal: upTotalStr, downTotal: dnTotalStr,
            totalRatio: quotaRatio
        )
        statusItem.length = menuBarView.frame.width
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
        return ceil(NSString(string: "999.9 GB").size(withAttributes: [.font: f]).width) + 5
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

    func update(upSpeed s1: String, downSpeed s2: String, upTotal t1: String, downTotal t2: String, totalRatio: Double = 0) {
        let bold9 = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        let reg9 = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        let rightStyle = NSMutableParagraphStyle()
        rightStyle.alignment = .right

        let totalColor = colorForRatio(totalRatio)

        upArrow.attributedStringValue = NSAttributedString(string: "▲", attributes: [.font: bold9, .foregroundColor: NSColor.systemOrange])
        downArrow.attributedStringValue = NSAttributedString(string: "▼", attributes: [.font: bold9, .foregroundColor: NSColor.systemBlue])
        upSpeed.attributedStringValue = NSAttributedString(string: s1, attributes: [.font: reg9, .foregroundColor: NSColor.white, .paragraphStyle: rightStyle])
        downSpeed.attributedStringValue = NSAttributedString(string: s2, attributes: [.font: reg9, .foregroundColor: NSColor.white, .paragraphStyle: rightStyle])
        upTotal.attributedStringValue = NSAttributedString(string: t1, attributes: [.font: bold9, .foregroundColor: totalColor, .paragraphStyle: rightStyle])
        downTotal.attributedStringValue = NSAttributedString(string: t2, attributes: [.font: bold9, .foregroundColor: totalColor, .paragraphStyle: rightStyle])

        [upArrow, downArrow, upSpeed, downSpeed, upTotal, downTotal].forEach { $0.sizeToFit() }

        let col1X: CGFloat = 1
        let col2X = col1X + upArrow.frame.width + 2
        let col3X = col2X + Self.col2FixedW + 3
        let w = col3X + Self.col3FixedW + 1

        let h = NSStatusBar.system.thickness
        let lineHeight = max(upArrow.frame.height, upSpeed.frame.height, upTotal.frame.height)
        let totalH = lineHeight * 2
        let baseY = (h - totalH) / 2

        upArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY + lineHeight))
        downArrow.setFrameOrigin(NSPoint(x: col1X, y: baseY))
        upSpeed.frame = NSRect(x: col2X, y: baseY + lineHeight, width: Self.col2FixedW, height: lineHeight)
        downSpeed.frame = NSRect(x: col2X, y: baseY, width: Self.col2FixedW, height: lineHeight)
        upTotal.frame = NSRect(x: col3X, y: baseY + lineHeight, width: Self.col3FixedW, height: lineHeight)
        downTotal.frame = NSRect(x: col3X, y: baseY, width: Self.col3FixedW, height: lineHeight)

        frame.size = NSSize(width: w, height: h)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    private func colorForRatio(_ ratio: Double) -> NSColor {
        if ratio < 0.6 {
            return .systemGreen
        } else if ratio < 0.85 {
            return .systemOrange
        } else {
            return .systemRed
        }
    }
}
