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

    init(locationManager: LocationManager) {
        self.locationManager = locationManager

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient

        super.init()

        setupMenuBar()
        setupPopover()
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
        let todayUsage = networkMonitor.todayUsage

        let uploadStr = formatSpeed(upload)
        let downloadStr = formatSpeed(download)
        let usageStr = formatBytes(todayUsage)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineSpacing = 0
        paragraphStyle.maximumLineHeight = 10

        let text = NSMutableAttributedString()
        let line1 = NSAttributedString(
            string: "▲ \(uploadStr)  ▼ \(downloadStr)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle
            ]
        )
        text.append(line1)
        text.append(NSAttributedString(string: "\n"))
        let line2 = NSAttributedString(
            string: usageStr,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor.systemGreen,
                .paragraphStyle: paragraphStyle
            ]
        )
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
        if bps >= 1_000_000_000 {
            return String(format: "%.1fGbps", bps / 1_000_000_000)
        } else if bps >= 1_000_000 {
            return String(format: "%.1fMbps", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.1fKbps", bps / 1_000)
        } else {
            return String(format: "%.0fbps", bps)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
