import SwiftUI

struct ProfileEditorView: View {
    let profile: Profile
    let currentSSID: String?
    let onClose: () -> Void
    let onProfilesChanged: () -> Void

    @State private var editName: String
    @State private var editQuotaEnabled: Bool
    @State private var editQuotaValue: String
    @State private var confirmDelete = false
    @State private var confirmDataReset = false
    @State private var quotaError: String?
    @State private var nameError: String?

    init(profile: Profile, currentSSID: String?, onClose: @escaping () -> Void, onProfilesChanged: @escaping () -> Void) {
        self.profile = profile
        self.currentSSID = currentSSID
        self.onClose = onClose
        self.onProfilesChanged = onProfilesChanged
        _editName = State(initialValue: profile.name)
        _editQuotaEnabled = State(initialValue: profile.quotaGB != nil)
        _editQuotaValue = State(initialValue: profile.quotaGB.map { String(format: "%.1f", $0) } ?? "")
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: TLSpace.xxl) {
                Text(Localized.profileEdit)
                    .font(TLFont.headline)
                    .padding(.top, TLSpace.xxl)

                VStack(spacing: TLSpace.lg) {
                    HStack {
                        Text(Localized.nameLabel).font(TLFont.body).foregroundColor(TLPalette.textSecondary).frame(width: 72, alignment: .trailing)
                        TextField(Localized.namePlaceholder, text: $editName)
                            .textFieldStyle(.roundedBorder)
                    }
                    if let nameError = nameError {
                        Text(nameError)
                            .font(TLFont.caption)
                            .foregroundColor(TLPalette.danger)
                            .padding(.leading, 88)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Text(Localized.ssidLabel).font(TLFont.body).foregroundColor(TLPalette.textSecondary).frame(width: 72, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: TLSpace.sm) {
                                Text(profile.ssid).font(TLFont.body).foregroundColor(TLPalette.textPrimary)
                                if profile.isHotspot {
                                    Text("(\(Localized.hotspot))").font(TLFont.body).foregroundColor(TLPalette.upload)
                                }
                            }
                            Text(Localized.string("네트워크 이름 (읽기전용)", "Network name (read-only)"))
                                .font(TLFont.caption2)
                                .foregroundColor(TLPalette.textSecondary)
                        }
                        Spacer()
                    }
                    HStack {
                        Text(Localized.quotaLabel).font(TLFont.body).foregroundColor(TLPalette.textSecondary).frame(width: 72, alignment: .trailing)
                        Toggle(Localized.quotaEnabled, isOn: $editQuotaEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: editQuotaEnabled) { _, _ in
                                quotaError = nil
                                nameError = nil
                            }
                        Spacer()
                    }
                    if editQuotaEnabled {
                        HStack {
                            Text(Localized.quotaGB).font(TLFont.body).foregroundColor(TLPalette.textSecondary).frame(width: 72, alignment: .trailing)
                            TextField(Localized.quotaPlaceholder, text: $editQuotaValue)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Spacer()
                        }
                        if let error = quotaError {
                            Text(error)
                                .font(TLFont.caption)
                                .foregroundColor(TLPalette.danger)
                                .padding(.leading, 88)
                        }
                    }
                }
                .padding(.horizontal, TLSpace.xxl)

                Spacer()

                HStack(spacing: TLSpace.md) {
                    Button(Localized.delete, role: .destructive) {
                        confirmDelete = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(Localized.resetData, role: .destructive) {
                        confirmDataReset = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button(Localized.cancel) { onClose() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button(Localized.save) {
                        quotaError = nil
                        nameError = nil
                        var updated = profile
                        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else {
                            nameError = Localized.nameRequired
                            return
                        }
                        updated.name = trimmedName
                        if editQuotaEnabled {
                            let trimmed = editQuotaValue.replacingOccurrences(of: ",", with: ".")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            guard let quota = Double(trimmed), quota > 0 else {
                                quotaError = Localized.quotaInvalid
                                return
                            }
                            updated.quotaGB = quota
                        } else {
                            updated.quotaGB = nil
                        }
                        ProfileManager.shared.saveProfile(updated)
                        onProfilesChanged()
                        NotificationCenter.default.post(name: .init("settingsChanged"), object: nil)
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, TLSpace.xxl)
            }
            .padding(.bottom, TLSpace.xxxl)
            .frame(maxHeight: .infinity)
            .frame(width: TLSize.sheetCompact)

            if confirmDelete {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: TLSpace.xxl) {
                    Text(Localized.confirm).font(TLFont.headline)
                    Text(Localized.profileDeleteConfirm)
                        .font(TLFont.body)
                        .multilineTextAlignment(.center)
                    HStack(spacing: TLSpace.xl) {
                        Button(Localized.cancel) { confirmDelete = false }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button(Localized.delete, role: .destructive) {
                            ProfileManager.shared.deleteProfile(id: profile.id)
                            if profile.ssid == currentSSID {
                                NotificationCenter.default.post(name: .init("currentProfileDeleted"), object: nil)
                            }
                            onProfilesChanged()
                            onClose()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(TLSpace.xxxl)
                .background(TLPalette.windowBackground)
                .cornerRadius(TLRound.medium)
                .shadow(radius: 10)
            }

            if confirmDataReset {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: TLSpace.xxl) {
                    Text(Localized.confirm).font(TLFont.headline)
                    Text(Localized.profileResetConfirm)
                        .font(TLFont.body)
                        .multilineTextAlignment(.center)
                    HStack(spacing: TLSpace.xl) {
                        Button(Localized.cancel) { confirmDataReset = false }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button(Localized.resetData, role: .destructive) {
                            ProfileManager.shared.deleteUsageData(profileId: profile.id)
                            NotificationCenter.default.post(name: .init("connectionChanged"), object: nil)
                            onProfilesChanged()
                            onClose()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(TLSpace.xxxl)
                .background(TLPalette.windowBackground)
                .cornerRadius(TLRound.medium)
                .shadow(radius: 10)
            }
        }
        .frame(width: TLSize.sheetCompact, height: 220)
    }
}
