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
            Text(Localized.savingModeTitle)
                .font(.headline)
                .padding(.top, 20)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localized.enableSavingMode)
                        Text(Localized.savingModeDescription)
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
                        Text(Localized.autoActivate)
                        Text(Localized.autoActivateDescription)
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
                Text(Localized.systemControl).font(.subheadline).foregroundColor(.secondary)

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

            Button(Localized.close, action: onClose)
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
                Label(Localized.stopSoftwareUpdates, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Label(Localized.stopTimeMachine, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Label(Localized.blockUpdateServers, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Button(Localized.deactivateSavingMode, role: .destructive) {
                applyDeactivate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isApplying)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(Localized.controlDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(Localized.controlItem1)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(Localized.controlItem2)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(Localized.controlItem3)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button(Localized.activateSavingMode) {
                applyActivate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isApplying)
        }
    }

    private func applyActivate() {
        isApplying = true
        statusMessage = Localized.applying
        SavingModeController.shared.activate { success, msg in
            Task { @MainActor in
                isApplying = false
                statusMessage = msg
                controllerActive = success
                if success {
                    SavingModeManager.shared.isEnabled = true
                    isEnabled = true
                }
            }
        }
    }

    private func applyDeactivate() {
        isApplying = true
        statusMessage = Localized.deactivating
        SavingModeController.shared.deactivate { success, msg in
            Task { @MainActor in
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
}
