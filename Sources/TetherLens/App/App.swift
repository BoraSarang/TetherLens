import SwiftUI

@main
struct TetherLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Settings {
            SettingsWindow()
        }

        Window(Localized.string("사용량 리포트", "Usage Report"), id: "usageReport") {
            UsageReportWindow()
        }
        .defaultSize(width: TLSize.reportWindow.w, height: TLSize.reportWindow.h)

        Window(Localized.string("앱 트래픽", "App Traffic"), id: "appTraffic") {
            AppTrafficWindow()
        }
        .defaultSize(width: TLSize.trafficWindow.w, height: TLSize.trafficWindow.h)

        Window(Localized.string("알림 목록", "Notifications"), id: "notifications") {
            NotificationsWindow()
        }
        .defaultSize(width: TLSize.notificationsWindow.w, height: TLSize.notificationsWindow.h)

        Window(Localized.string("정보", "About"), id: "about") {
            AboutWindow()
        }
        .defaultSize(width: TLSize.aboutWindow.w, height: TLSize.aboutWindow.h)
    }
}

// 시트 → 별도 Window 전환 (v0.29): 닫기 버튼은 @Environment(\.dismiss)로 처리
private struct SettingsWindow: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        SettingsView(onClose: { dismiss() })
    }
}

private struct UsageReportWindow: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        UsageReportView(onClose: { dismiss() })
    }
}

private struct AppTrafficWindow: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        AppTrafficView(onClose: { dismiss() })
    }
}

private struct NotificationsWindow: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NotificationListView(onClose: { dismiss() })
    }
}

private struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        AboutView(onClose: { dismiss() })
    }
}