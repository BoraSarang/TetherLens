import AppKit
import SwiftUI
import Combine

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
    private var appsCancellable: AnyCancellable?
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
        let rssi = Int(info["rssi"] as? String ?? "") ?? -1000
        let latencyMS = Int(info["latencyMS"] as? String ?? "") ?? -1
        viewModel.update(
            upSpeed: up, downSpeed: down,
            col3Top: col3Top, col3Bottom: col3Bottom,
            totalRatio: ratio,
            col3IsUsage: info["col3IsUsage"] as? Bool ?? false,
            col3IsLatency: info["col3IsLatency"] as? Bool ?? false,
            rssi: rssi,
            latencyMS: latencyMS,
            isReachable: info["reachable"] as? Bool ?? true
        )
        // 폭은 사용자가 리사이즈 가능, 높이는 fitToContent()가 내용에 맞춘다
    }

    /// 설정 창에서 줄 토글이 바뀌면 떠 있는 동안만 즉시 반영한다.
    @objc private func handleFloatingSettingsChanged() {
        guard isVisible else { return }
        setTrafficMonitoring(SettingsManager.shared.floatingVisibleLines > 0)
        fitToContent()
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

    /// 콘텐츠 실측 기반 자동 높이 (v0.32.2) — 줄 토글·수집 상태·폰트에 따라 패널이 스스로 맞춘다.
    /// 상단 고정(아래로 자람), 화면 밖으로 나가지 않게 클램프. 40~420 범위로 제한.
    func fitToContent() {
        guard let panel, panel.isVisible,
              let hosting = panel.contentViewController else { return }
        hosting.view.layoutSubtreeIfNeeded()
        var h = hosting.view.fittingSize.height
        guard h > 0, h.isFinite else { return }
        h = min(max(h, 40), 420)
        guard abs(h - panel.frame.height) > 1 else { return }
        let screenFrame = NSScreen.main?.visibleFrame ?? panel.frame
        var origin = panel.frame.origin
        origin.y += panel.frame.height - h
        origin.x = min(max(origin.x, screenFrame.minX), max(screenFrame.maxX - panel.frame.width, screenFrame.minX))
        origin.y = min(max(origin.y, screenFrame.minY), max(screenFrame.maxY - h, screenFrame.minY))
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: panel.frame.width, height: h)), display: true)
        DebugLogger.shared.action("Floating", "자동 높이 적용=\(Int(h))")
    }

    /// 수집 결과가 갱신될 때마다 높이 재적합 (수집 중 문구 ↔ 3줄 전환 대응).
    private func observeApps() {
        guard appsCancellable == nil else { return }
        appsCancellable = TrafficMonitor.shared.$apps
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.fitToContent() }
            }
    }

    func show() {
        if let panel, panel.isVisible {
            panel.orderFront(nil)
            return
        }
        if panel == nil {
            let hosting = NSHostingController(rootView: FloatingWindowView().environmentObject(viewModel))
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            // 기본 크기 — 표시 직후 fitToContent()가 실측으로 맞추므로 추정값으로 시작
            let size = NSSize(width: 300, height: 132)
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
            // Tahoe는 hasShadow와 함께 창 경계에 글래스 엣지(밝은 림)를 그린다 (TetherLens-vie) → 테두리 없는 외관을 위해 그림자 OFF
            win.hasShadow = false
            win.isMovableByWindowBackground = true
            win.isReleasedWhenClosed = false
            win.contentViewController = hosting
            panel = win
            observeMove(win)
            observeApps()
            DebugLogger.shared.action("Floating", "창 생성 위치=\(origin) 크기=\(size)")
        }
        setTrafficMonitoring(SettingsManager.shared.floatingVisibleLines > 0)
        panel?.orderFront(nil)
        fitToContent()
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
    @Published var col3IsLatency = false
    @Published var rssi = -1000
    @Published var latencyMS = -1
    @Published var isReachable = true

    func update(upSpeed: String, downSpeed: String, col3Top: String, col3Bottom: String, totalRatio: Double, col3IsUsage: Bool, col3IsLatency: Bool = false, rssi: Int = -1000, latencyMS: Int = -1, isReachable: Bool = true) {
        self.upSpeed = upSpeed
        self.downSpeed = downSpeed
        self.col3Top = col3Top
        self.col3Bottom = col3Bottom
        self.totalRatio = totalRatio
        self.col3IsUsage = col3IsUsage
        self.col3IsLatency = col3IsLatency
        self.rssi = rssi
        self.latencyMS = latencyMS
        self.isReachable = isReachable
    }
}