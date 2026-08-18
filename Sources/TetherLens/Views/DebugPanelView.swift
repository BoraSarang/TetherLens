import SwiftUI

struct DebugPanelView: View {
    @ObservedObject var logger = DebugLogger.shared
    @State private var selectedIDs: Set<UUID> = []
    @State private var lastSelectedID: UUID?
    @State private var autoScroll = true
    @State private var pauseWork: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(logger.logs) { entry in
                            Text("[\(entry.timestamp)] [\(entry.level.rawValue)] [\(entry.platform)] [\(entry.category)] \(entry.message)\(entry.meta.map { " | meta=\($0)" } ?? "")")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(selectedIDs.contains(entry.id) ? Color.white : textColor(for: entry.level))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(selectedIDs.contains(entry.id) ? Color.accentColor : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTap(entry)
                                }
                                .id(entry.id)
                        }
                    }
                }
                .background(Color(.textBackgroundColor))
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        pauseAutoScroll()
                    }
                )
                .onChange(of: logger.logs.count) { _, _ in
                    guard autoScroll, let lastID = logger.logs.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: TLSpace.sm) {
            Image(systemName: "ladybug")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.secondary)
            Text("[MAC] \(Localized.string("디버그 로그", "Debug Logs")) [\(logger.logs.count)]")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.primary)
            Spacer()

            Button(selectedIDs.isEmpty
                ? Localized.string("선택 복사", "Copy Selected")
                : String(format: Localized.string("선택 복사 (%d줄)", "Copy Selected (%d lines)"), selectedIDs.count)) {
                copySelection()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundColor(selectedIDs.isEmpty ? Color.secondary : Color.accentColor)
            .disabled(selectedIDs.isEmpty)

            Button(Localized.string("선택 해제", "Deselect")) {
                selectedIDs.removeAll()
                lastSelectedID = nil
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundColor(selectedIDs.isEmpty ? Color.secondary : Color.accentColor)
            .disabled(selectedIDs.isEmpty)

            Button {
                autoScroll.toggle()
            } label: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(autoScroll ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(autoScroll
                ? Localized.string("자동 스크롤 켜짐 (클릭시 끔)", "Auto-scroll on (click to turn off)")
                : Localized.string("자동 스크롤 꺼짐 (클릭시 켬)", "Auto-scroll off (click to turn on)"))

            Button(Localized.string("전체 복사", "Copy All")) { copyAll() }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .foregroundColor(Color.secondary)

            Button(Localized.string("클리어", "Clear")) {
                logger.clear()
                selectedIDs.removeAll()
                lastSelectedID = nil
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundColor(Color.secondary)

            Divider()
                .frame(height: 12)

            Button {
                DebugPanelController.shared.hide()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(Localized.string("닫기", "Close"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func pauseAutoScroll() {
        autoScroll = false
        pauseWork?.cancel()
        let work = DispatchWorkItem { autoScroll = true }
        pauseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func handleTap(_ entry: DebugLogEntry) {
        pauseAutoScroll()
        if NSEvent.modifierFlags.contains(.shift), let last = lastSelectedID {
            let ids = logger.logs.map(\.id)
            if let currentIdx = ids.firstIndex(of: entry.id),
               let lastIdx = ids.firstIndex(of: last) {
                let range = min(lastIdx, currentIdx)...max(lastIdx, currentIdx)
                selectedIDs.formUnion(logger.logs[range].map(\.id))
            }
        } else if NSEvent.modifierFlags.contains(.command) {
            selectedIDs.toggle(entry.id)
            lastSelectedID = entry.id
        } else {
            selectedIDs = [entry.id]
            lastSelectedID = entry.id
        }
    }

    private func copyAll() {
        let text = logger.formatForAgent(logger.logs)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copySelection() {
        let text = logger.logs
            .filter { selectedIDs.contains($0.id) }
            .map { "[\($0.timestamp)] [\($0.level.rawValue)] [\($0.platform)] [\($0.category)] \($0.message)\($0.meta.map { " | meta=\($0)" } ?? "")" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func textColor(for level: DebugLogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warn: return .yellow
        case .apiReq: return .blue
        case .apiRes: return .green
        case .action: return .primary
        case .system: return .purple
        case .info: return .secondary
        }
    }
}

extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) }
        else { insert(element) }
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
