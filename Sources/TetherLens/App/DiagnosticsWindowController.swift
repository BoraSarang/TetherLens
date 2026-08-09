import AppKit
import SwiftUI

/// 네트워크 진단 센터 패널을 관리한다 (floating NSWindow).
@MainActor
final class DiagnosticsWindowController {
    static let shared = DiagnosticsWindowController()

    private var window: NSWindow?
    private var hostingController: NSHostingController<DiagnosticsView>?

    private init() {}

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }
        if window == nil {
            hostingController = NSHostingController(rootView: DiagnosticsView())
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            let panelSize = NSSize(width: 520, height: 560)
            let origin = NSPoint(
                x: screenFrame.midX - panelSize.width / 2,
                y: screenFrame.midY - panelSize.height / 2
            )
            let win = NSWindow(
                contentRect: NSRect(origin: origin, size: panelSize),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "네트워크 진단"
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.contentViewController = hostingController
            win.setFrameAutosaveName("DiagnosticsWindow")
            win.minSize = NSSize(width: 460, height: 460)
            win.level = .floating + 100
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.isReleasedWhenClosed = false
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}