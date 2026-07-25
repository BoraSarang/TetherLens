import SwiftUI

struct SavingModeSheet: View {
    @State private var isEnabled: Bool
    @State private var autoActivate: Bool
    @State private var controllerActive = false
    @State private var statusMessage: String?
    @State private var isApplying = false

    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _isEnabled = State(initialValue: SavingModeManager.shared.isEnabled)
        _autoActivate = State(initialValue: SavingModeManager.shared.autoActivate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("절약 모드")
                .font(.headline)
                .padding(.top, 20)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("절약 모드 활성화")
                        Text("QoS 색상 기준이 더 엄격해집니다")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: isEnabled) { _, newValue in
                    SavingModeManager.shared.isEnabled = newValue
                }

                Toggle(isOn: $autoActivate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("자동 활성화")
                        Text("할당량 80% 도달 시 자동으로 켜집니다")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: autoActivate) { _, newValue in
                    SavingModeManager.shared.autoActivate = newValue
                }
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("시스템 제어").font(.subheadline).foregroundColor(.secondary)

                statusSection
            }
            .padding(.horizontal, 20)

            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(isApplying ? .secondary : controllerActive ? .green : .red)
                    .padding(.horizontal, 20)
            }

            Spacer()

            Button("닫기", action: onClose)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
        }
        .frame(width: 300, height: 380)
        .onAppear {
            controllerActive = SavingModeController.shared.isActive()
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if controllerActive {
            VStack(alignment: .leading, spacing: 4) {
                Label("소프트웨어 업데이트 중지", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Label("Time Machine 백업 중지", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Label("업데이트 서버 차단 중", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Button("절약 모드 해제", role: .destructive) {
                applyDeactivate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isApplying)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("관리자 비밀번호로 다음 항목을 제어합니다")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• 소프트웨어 업데이트 중지")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Time Machine 백업 중지")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• 업데이트/설치 서버 차단")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button("절약 모드 적용") {
                applyActivate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isApplying)
        }
    }

    private func applyActivate() {
        isApplying = true
        statusMessage = "적용 중..."
        SavingModeController.shared.activate { success, msg in
            isApplying = false
            statusMessage = msg
            controllerActive = success
            if success {
                SavingModeManager.shared.isEnabled = true
                isEnabled = true
            }
        }
    }

    private func applyDeactivate() {
        isApplying = true
        statusMessage = "해제 중..."
        SavingModeController.shared.deactivate { success, msg in
            isApplying = false
            statusMessage = msg
            controllerActive = !success
            if success {
                SavingModeManager.shared.isEnabled = false
                isEnabled = false
            }
        }
    }
}
