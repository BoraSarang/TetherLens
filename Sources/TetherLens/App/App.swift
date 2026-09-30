import SwiftUI

@main
struct TetherLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        registerShortcutsOnce()
        return scenes
    }

    /// ⌘ 단축키는 LSUIElement 앱이라 `.commands`의 keyboardShortcut가 발화하지 않는다.
    /// 실제 처리는 AppShortcuts(NSEvent 모니터)이며, `openWindow`가 필요한 항목만 여기서 등록한다.
    private func registerShortcutsOnce() {
        let open = openWindow
        AppShortcuts.shared.registerDefaultsOnce {
            AppShortcuts.shared.register("cmd+1") { open(id: "usageReport") }
            AppShortcuts.shared.register("cmd+2") { open(id: "appTraffic") }
            AppShortcuts.shared.register("cmd+3") { open(id: "notifications") }
            AppShortcuts.shared.register("cmd+4") { open(id: "about") }
            AppShortcuts.shared.register("cmd+k") { open(id: "commandPalette") }
            AppShortcuts.shared.register("cmd+5") { open(id: "dashboard") }
        }
    }

    @SceneBuilder
    private var scenes: some Scene {
        Settings {
            SettingsWindow()
        }
        .commands {
            // 주의: 아래 keyboardShortcut는 LSUIElement(.accessory) 정책에서는 발화하지 않는다.
            // 실제로 동작하는 경로는 AppShortcuts(AppShortcuts.swift)다. 메뉴는 접근성/검색 용도로 유지한다.
            CommandGroup(after: .windowArrangement) {
                Divider()
                Button(Localized.usageReport) { openWindow(id: "usageReport") }
                    .keyboardShortcut("1", modifiers: .command)
                Button(Localized.appTrafficButton) { openWindow(id: "appTraffic") }
                    .keyboardShortcut("2", modifiers: .command)
                Button(Localized.notificationList) { openWindow(id: "notifications") }
                    .keyboardShortcut("3", modifiers: .command)
                Button(Localized.about) { openWindow(id: "about") }
                    .keyboardShortcut("4", modifiers: .command)
                Button(Localized.dashboard) { openWindow(id: "dashboard") }
                    .keyboardShortcut("5", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Divider()
                Button(Localized.floatingWindowShow) { FloatingWindowController.shared.toggle() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Button(Localized.popoverToggle) {
                    NotificationCenter.default.post(name: .init("togglePopover"), object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                #if DEBUG
                Button(Localized.debugPanel) { DebugPanelController.shared.toggle() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                #endif
                Divider()
                Button(Localized.commandPalette) { openWindow(id: "commandPalette") }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }

        Window(Localized.commandPalette, id: "commandPalette") {
            CommandPaletteView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 320)

        Window(Localized.string("사용량 리포트", "Usage Report"), id: "usageReport") {
            UsageReportWindow()
        }
        .defaultSize(width: TLSize.reportWindow.w, height: TLSize.reportWindow.h)
        .windowResizability(.contentMinSize)

        Window(Localized.string("시스템 대시보드", "System Dashboard"), id: "appTraffic") {
            AppTrafficWindow()
        }
        .defaultSize(width: TLSize.trafficWindow.w, height: TLSize.trafficWindow.h)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window(Localized.string("알림 목록", "Notifications"), id: "notifications") {
            NotificationsWindow()
        }
        .defaultSize(width: TLSize.notificationsWindow.w, height: TLSize.notificationsWindow.h)

        Window(Localized.string("정보", "About"), id: "about") {
            AboutWindow()
        }
        .defaultSize(width: TLSize.aboutWindow.w, height: TLSize.aboutWindow.h)
        .windowResizability(.contentSize)

        // 대시보드 (v0.39) — 메뉴바 팝오버 '상세 보기'의 대체 통합 관제 화면
        Window(Localized.dashboard, id: "dashboard") {
            DashboardView()
        }
        .defaultSize(width: TLSize.dashboardWindow.w, height: TLSize.dashboardWindow.h)
        .windowResizability(.contentMinSize)
    }
}

// 시트 → 별도 Window 전환 (v0.29): 닫기 버튼은 시스템 창 닫기로 처리
private struct SettingsWindow: View {
    var body: some View {
        SettingsView()
    }
}

private struct UsageReportWindow: View {
    var body: some View {
        UsageReportView()
    }
}

private struct AppTrafficWindow: View {
    var body: some View {
        AppTrafficView()
    }
}

private struct NotificationsWindow: View {
    var body: some View {
        NotificationListView()
    }
}

private struct AboutWindow: View {
    var body: some View {
        AboutView()
    }
}