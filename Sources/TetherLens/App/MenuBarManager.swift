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

        menuBarView.setAttributedText(text)
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

class MenuBarView: NSView {
    private var attrString: NSAttributedString?
    var onClick: (() -> Void)?

    var textWidth: CGFloat {
        guard let attr = attrString else { return 40 }
        return attr.size().width + 12
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) { nil }

    func setAttributedText(_ attr: NSAttributedString) {
        attrString = attr
        let w = textWidth
        let h = NSStatusBar.system.thickness
        frame.size = NSSize(width: w, height: h)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let attr = attrString else { return }
        let textSize = attr.size()
        let x = (bounds.width - textSize.width) / 2
        let y = (bounds.height - textSize.height) / 2
        attr.draw(at: NSPoint(x: x, y: y))
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
