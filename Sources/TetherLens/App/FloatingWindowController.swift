import AppKit
import SwiftUI

/// 메뉴바 표시 내용(설정 연동)을 바탕화면에 띄우는 플로팅 창을 관리한다 (v0.31).
/// - borderless NSPanel + `.floating` 레벨 → 항상 위에 떠 있는 비활성 패널
/// - `isMovableByWindowBackground`로 드래그 이동 + UserDefaults 위치 저장/복원
/// - 트래픽 상위 3개 표시 시 `TrafficMonitor` 참조를 유일하게 소유한다 (acquire/release 균형)
@MainActor
final class FloatingWindowController {
    static let shared = FloatingWindowController()

    private(set) var panel: NSPanel?
    private let viewModel = FloatingWindowViewModel()
    private var moveObserver: NSObjectProtocol?
    private var trafficAcquired = false

    private static let originKey = "floatingWindowOrigin"

    var isVisible: Bool { panel?.isVisible == true }

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFloatingContent),
            name: .init("floatingContentChanged"), object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleFloatingSettingsChanged),
            name: .init("floatingSettingsChanged"), object: nil
        )
    }

    /// MenuBarManager가 메뉴바 표시 내용을 계산할 때마다 발행된다 → 설정·tick 경로에서 자동 동기화.
    @objc private func handleFloatingContent(_ note: Notification) {
        guard let info = note.userInfo,
              let up = info["up"] as? String,
              let down = info["down"] as? String,
              let col3Top = info["col3Top"] as? String,
              let col3Bottom = info["col3Bottom"] as? String,
              let ratio = info["ratio"] as? Double else { return }
        viewModel.update(
            upSpeed: up, downSpeed: down,
            col3Top: col3Top, col3Bottom: col3Bottom,
            totalRatio: ratio,
            col3IsUsage: info["col3IsUsage"] as? Bool ?? false
        )
        // 폭은 사용자가 리사이즈 가능, 세로는 설정 토글 변경 시 applyFixedHeight()가 유지한다
    }

    /// 설정 창에서 트래픽 토글이 바뀌면 떠 있는 동안만 즉시 반영한다.
    @objc private func handleFloatingSettingsChanged() {
        guard isVisible else { return }
        setTrafficMonitoring(SettingsManager.shared.floatingShowTraffic)
        applyFixedHeight()
    }

    /// acquire/release는 이 컨트롤러가 유일하게 관리한다 (중복 콜로 balance 어긋남 방지).
    private func setTrafficMonitoring(_ enabled: Bool) {
        guard trafficAcquired != enabled else { return }
        if enabled {
            TrafficMonitor.shared.acquire(reason: .floating)
            trafficAcquired = true
        } else {
            TrafficMonitor.shared.release(reason: .floating)
            trafficAcquired = false
        }
        DebugLogger.shared.action("Floating", "트래픽 모니터링 \(enabled ? "ON" : "OFF")")
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    /// 세로 크기를 프로세스 리스트 표시 여부에 따라 고정한다.
    /// - 리스트 ON: 트래픽 헤더 + 상위 3행이 온전히 보이는 높이
    /// - 리스트 OFF: 속도·사용량만 표시되는 콤팩트 높이
    func applyFixedHeight() {
        guard let panel else { return }
        let targetH: CGFloat = SettingsManager.shared.floatingShowTraffic ? 120 : 40
        guard abs(targetH - panel.frame.height) > 1 else { return }
        let screenFrame = NSScreen.main?.visibleFrame ?? panel.frame
        var origin = panel.frame.origin
        origin.x = min(max(origin.x, screenFrame.minX), max(screenFrame.maxX - panel.frame.width, screenFrame.minX))
        origin.y = min(max(origin.y, screenFrame.minY), max(screenFrame.maxY - targetH, screenFrame.minY))
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: panel.frame.width, height: targetH)), display: true)
        DebugLogger.shared.action("Floating", "고정 높이 적용=\(Int(targetH)) (트래픽 \(SettingsManager.shared.floatingShowTraffic ? "ON" : "OFF"))")
    }

    func show() {
        if let panel, panel.isVisible {
            panel.orderFront(nil)
            return
        }
        if panel == nil {
            let hosting = NSHostingController(rootView: FloatingWindowView().environmentObject(viewModel))
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            // 기본 크기 — 세로는 프로세스 리스트 표시 여부에 따른 고정값 (리스트 ON 120 / OFF 40)
            let size = NSSize(width: 300, height: SettingsManager.shared.floatingShowTraffic ? 120 : 40)
            var origin = savedOrigin ?? NSPoint(
                x: screenFrame.maxX - size.width - 20,
                y: screenFrame.maxY - size.height - 36
            )
            origin.x = min(max(origin.x, screenFrame.minX), max(screenFrame.maxX - size.width, screenFrame.minX))
            origin.y = min(max(origin.y, screenFrame.minY), max(screenFrame.maxY - size.height, screenFrame.minY))

            let win = NSPanel(
                contentRect: NSRect(origin: origin, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            win.level = .floating
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.isMovableByWindowBackground = true
            win.isReleasedWhenClosed = false
            win.contentViewController = hosting
            // contentViewController 배정 시 창이 콘텐츠 크기로 자동 재조정될 수 있어 크기를 다시 명시 고정
            win.setContentSize(NSSize(width: 300, height: SettingsManager.shared.floatingShowTraffic ? 120 : 40))
            panel = win
            observeMove(win)
            DebugLogger.shared.action("Floating", "창 생성 위치=\(origin) 크기=\(size)")
        }
        setTrafficMonitoring(SettingsManager.shared.floatingShowTraffic)
        panel?.orderFront(nil)
        applyFixedHeight()
        DebugLogger.shared.action("Floating", "플로팅 창 표시")
    }

    func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        setTrafficMonitoring(false)
        DebugLogger.shared.action("Floating", "플로팅 창 숨김")
    }

    private func observeMove(_ panel: NSPanel) {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] note in
            guard let win = note.object as? NSWindow else { return }
            self?.savedOrigin = win.frame.origin
        }
    }

    private var savedOrigin: NSPoint? {
        get {
            guard let s = UserDefaults.standard.string(forKey: Self.originKey) else { return nil }
            let parts = s.split(separator: ",").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }
            return NSPoint(x: parts[0], y: parts[1])
        }
        set {
            if let p = newValue {
                UserDefaults.standard.set("\(p.x),\(p.y)", forKey: Self.originKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.originKey)
            }
        }
    }
}

/// MenuBarManager가 발행하는 메뉴바 표시 문자열을 플로팅 뷰에 바인딩한다.
@MainActor
final class FloatingWindowViewModel: ObservableObject {
    @Published var upSpeed = ""
    @Published var downSpeed = ""
    @Published var col3Top = ""
    @Published var col3Bottom = ""
    @Published var totalRatio: Double = -1
    @Published var col3IsUsage = false

    func update(upSpeed: String, downSpeed: String, col3Top: String, col3Bottom: String, totalRatio: Double, col3IsUsage: Bool) {
        self.upSpeed = upSpeed
        self.downSpeed = downSpeed
        self.col3Top = col3Top
        self.col3Bottom = col3Bottom
        self.totalRatio = totalRatio
        self.col3IsUsage = col3IsUsage
    }
}