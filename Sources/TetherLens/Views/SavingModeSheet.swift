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
        VStack(alignment: .leading, spacing: TLSpace.xxl) {
            Text(Localized.savingModeTitle)
                .font(TLFont.headline)
                .padding(.top, TLSpace.xxxl)
                .frame(maxWidth: .infinity)

            VStack(spacing: TLSpace.xl) {
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localized.enableSavingMode)
                        Text(Localized.savingModeDescription)
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textSecondary)
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
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: autoActivate) { _, newValue in
                    SavingModeManager.shared.autoActivate = newValue
                }
            }
            .padding(.horizontal, TLSpace.xxxl)

            Divider()
                .padding(.horizontal, TLSpace.xxxl)

            VStack(alignment: .leading, spacing: TLSpace.md) {
                Text(Localized.systemControl).font(TLFont.subheadline).foregroundColor(TLPalette.textSecondary)

                statusSection
            }
            .padding(.horizontal, TLSpace.xxxl)

            if let msg = statusMessage {
                Text(msg)
                    .font(TLFont.caption)
                    .foregroundColor(isApplying ? TLPalette.textSecondary : controllerActive ? TLPalette.success : TLPalette.danger)
                    .padding(.horizontal, TLSpace.xxxl)
            }

            Spacer()

            Button(Localized.close, action: onClose)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, TLSpace.xxxl)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, TLSpace.xxxl)
        }
        .frame(width: TLSize.sheetSaving, height: 380)
        .onAppear {
            controllerActive = SavingModeController.shared.isActive()
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if controllerActive {
            VStack(alignment: .leading, spacing: TLSpace.xs) {
                Label(Localized.stopSoftwareUpdates, systemImage: "checkmark.circle.fill")
                    .foregroundColor(TLPalette.success)
                    .font(TLFont.caption)
                Label(Localized.stopTimeMachine, systemImage: "checkmark.circle.fill")
                    .foregroundColor(TLPalette.success)
                    .font(TLFont.caption)
                Label(Localized.blockUpdateServers, systemImage: "checkmark.circle.fill")
                    .foregroundColor(TLPalette.success)
                    .font(TLFont.caption)
            }

            Button(Localized.deactivateSavingMode, role: .destructive) {
                applyDeactivate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isApplying)
        } else {
            VStack(alignment: .leading, spacing: TLSpace.xs) {
                Text(Localized.controlDescription)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                Text(Localized.controlItem1)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                Text(Localized.controlItem2)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                Text(Localized.controlItem3)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
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
