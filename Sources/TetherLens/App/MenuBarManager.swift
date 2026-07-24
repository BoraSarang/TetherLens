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
    private let locationManager: LocationManager

    private var isPopoverShown = false

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
            NotificationCenter.default.post(name: connectionChanged, object: nil)
        }
    }

    private func setupMenuBar() {
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateMenuBarText()
        }
    }

    private func setupPopover() {
        let contentView = PopoverView(
            networkMonitor: networkMonitor,
            hotspotDetector: hotspotDetector,
            pingMonitor: pingMonitor
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    func startMonitoring() {
        networkMonitor.start()
        hotspotDetector.start()
        pingMonitor.start()

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
        guard let button = statusItem.button else { return }

        let upload = networkMonitor.currentUploadSpeed
        let download = networkMonitor.currentDownloadSpeed
        let totalUpload = networkMonitor.totalUpload
        let totalDownload = networkMonitor.totalDownload

        let uploadStr = formatSpeed(upload)
        let downloadStr = formatSpeed(download)
        let upTotalStr = formatBytes(totalUpload)
        let dnTotalStr = formatBytes(totalDownload)

        let style = NSMutableParagraphStyle()
        let tab1 = NSTextTab(textAlignment: .right, location: 80, options: [:])
        let tab2 = NSTextTab(textAlignment: .right, location: 130, options: [:])
        style.tabStops = [tab1, tab2]
        style.lineSpacing = 0
        style.maximumLineHeight = 10

        let text = NSMutableAttributedString()

        let line1 = NSMutableAttributedString()
        line1.append(NSAttributedString(string: "▲", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.systemOrange,
            .paragraphStyle: style
        ]))
        line1.append(NSAttributedString(string: "\t\(uploadStr)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]))
        line1.append(NSAttributedString(string: "\t\(upTotalStr)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.systemGray,
            .paragraphStyle: style
        ]))
        text.append(line1)
        text.append(NSAttributedString(string: "\n"))

        let line2 = NSMutableAttributedString()
        line2.append(NSAttributedString(string: "▼", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.systemBlue,
            .paragraphStyle: style
        ]))
        line2.append(NSAttributedString(string: "\t\(downloadStr)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]))
        line2.append(NSAttributedString(string: "\t\(dnTotalStr)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.systemGray,
            .paragraphStyle: style
        ]))
        text.append(line2)

        button.attributedTitle = text
        button.sizeToFit()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func formatSpeed(_ bps: Double) -> String {
        let Bps = bps / 8
        if Bps >= 1_000_000_000 {
            return String(format: "%.2f GB/s", Bps / 1_000_000_000)
        } else if Bps >= 1_000_000 {
            return String(format: "%.2f MB/s", Bps / 1_000_000)
        } else if Bps >= 1_000 {
            return String(format: "%.2f KB/s", Bps / 1_000)
        } else {
            return String(format: "%.0f B/s", Bps)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
}
