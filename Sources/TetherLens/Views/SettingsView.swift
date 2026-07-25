import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var showTotalColumn: Bool
    @State private var launchAtLogin: Bool

    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _showTotalColumn = State(initialValue: SettingsManager.shared.showTotalColumn)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("설정")
                .font(.headline)
                .padding(.top, 20)
                .frame(maxWidth: .infinity)

            Toggle("메뉴바에 총 사용량 표시", isOn: $showTotalColumn)
                .padding(.horizontal, 20)
                .onChange(of: showTotalColumn) { _, newValue in
                    SettingsManager.shared.showTotalColumn = newValue
                    NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                }

            Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                .padding(.horizontal, 20)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Spacer()

            HStack {
                Spacer()
                Button("닫기", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 260, height: 190)
    }
}
