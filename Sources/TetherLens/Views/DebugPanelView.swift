import SwiftUI

struct DebugPanelView: View {
    @ObservedObject var logger = DebugLogger.shared
    @State private var selectedLineIndices: Set<Int> = []
    @State private var lastSelectedIndex: Int?
    @State private var autoScroll = true
    @State private var pauseWork: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("🐛 [MAC] Debug Logs [\(logger.logs.count)]")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Button(selectedLineIndices.isEmpty ? "선택 복사" : "선택 복사 (\(selectedLineIndices.count)줄)") {
                    copySelection()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(selectedLineIndices.isEmpty ? .white.opacity(0.4) : .white.opacity(0.7))
                .disabled(selectedLineIndices.isEmpty)
                Button("선택 해제") {
                    selectedLineIndices.removeAll()
                    lastSelectedIndex = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(selectedLineIndices.isEmpty ? .white.opacity(0.4) : .white.opacity(0.7))
                .disabled(selectedLineIndices.isEmpty)
                Button("📌") { autoScroll.toggle() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(autoScroll ? .green : .white.opacity(0.3))
                    .help(autoScroll ? "자동 스크롤 켜짐 (클릭시 끔)" : "자동 스크롤 꺼짐 (클릭시 켬)")
                Button("전체 복사") { copyAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                Button("클리어") {
                    logger.clear()
                    selectedLineIndices.removeAll()
                    lastSelectedIndex = nil
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                Button("X") { DebugPanelController.shared.hide() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.85))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(logger.logs.enumerated()), id: \.offset) { index, entry in
                            Text("[\(entry.timestamp)] [\(entry.level.rawValue)] [\(entry.platform)] [\(entry.category)] \(entry.message)\(entry.meta.map { " | meta=\($0)" } ?? "")")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(selectedLineIndices.contains(index) ? .white : textColor(for: entry.level))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(selectedLineIndices.contains(index) ? Color.accentColor : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTap(at: index)
                                }
                                .id(index)
                        }
                    }
                }
                .background(Color.black.opacity(0.92))
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        pauseAutoScroll()
                    }
                )
                .onChange(of: logger.logs.count) { _, _ in
                    guard autoScroll else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(logger.logs.count - 1, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func pauseAutoScroll() {
        autoScroll = false
        pauseWork?.cancel()
        let work = DispatchWorkItem { autoScroll = true }
        pauseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func handleTap(at index: Int) {
        pauseAutoScroll()
        if NSEvent.modifierFlags.contains(.shift), let last = lastSelectedIndex {
            let range = min(last, index)...max(last, index)
            selectedLineIndices.formUnion(range)
        } else if NSEvent.modifierFlags.contains(.command) {
            selectedLineIndices.toggle(index)
            lastSelectedIndex = index
        } else {
            selectedLineIndices = [index]
            lastSelectedIndex = index
        }
    }

    private func copyAll() {
        let text = logger.formatForAgent(logger.logs)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copySelection() {
        let text = selectedLineIndices.sorted()
            .compactMap { logger.logs[safe: $0] }
            .map { "[\($0.timestamp)] [\($0.level.rawValue)] [\($0.platform)] [\($0.category)] \($0.message)\($0.meta.map { " | meta=\($0)" } ?? "")" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func textColor(for level: DebugLogLevel) -> Color {
        switch level {
        case .error: return Color(red: 1, green: 0.42, blue: 0.42)
        case .warn: return Color(red: 1, green: 0.84, blue: 0.3)
        case .apiReq: return Color(red: 0.45, green: 0.75, blue: 0.99)
        case .apiRes: return Color(red: 0.55, green: 0.92, blue: 0.6)
        case .action: return .white
        case .system: return Color(red: 0.7, green: 0.5, blue: 0.95)
        case .info: return Color(white: 0.7)
        }
    }
}

extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) }
        else { insert(element) }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

@MainActor
final class DebugPanelController {
    static let shared = DebugPanelController()
    var isVisible: Bool { window?.isVisible == true }
    var window: NSWindow?
    private var hostingController: NSHostingController<DebugPanelView>?

    private init() {}

    func show() {
        if let window, window.isVisible { window.makeKeyAndOrderFront(nil); return }
        if window == nil {
            let panelView = DebugPanelView()
            hostingController = NSHostingController(rootView: panelView)
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let panelSize = NSSize(width: 600, height: 320)
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
            win.title = ""
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.contentViewController = hostingController
            win.setFrameAutosaveName("DebugPanelWindow")
            win.center()
            win.minSize = NSSize(width: 400, height: 200)
            win.maxSize = NSSize(width: 2000, height: 1200)
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

    func toggle() {
        DebugLogger.shared.action("UI", "디버그 패널 토글 (visible=\(window?.isVisible == true))")
        if window?.isVisible == true { hide() } else { show() }
    }
}
