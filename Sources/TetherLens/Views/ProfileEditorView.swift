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
            VStack(spacing: 16) {
                Text(Localized.profileEdit)
                    .font(.headline)
                    .padding(.top, 16)

                VStack(spacing: 10) {
                    HStack {
                        Text(Localized.nameLabel).font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                        TextField(Localized.namePlaceholder, text: $editName)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text(Localized.ssidLabel).font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Text(profile.ssid).font(.body).foregroundColor(.primary)
                                if profile.isHotspot {
                                    Text("(\(Localized.hotspot))").font(.body).foregroundColor(.orange)
                                }
                            }
                            Text(Localized.string("네트워크 이름 (읽기전용)", "Network name (read-only)"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    HStack {
                        Text(Localized.quotaLabel).font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                        Toggle(isOn: $editQuotaEnabled) { EmptyView() }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        Text(Localized.quotaEnabled).font(.body).foregroundColor(.secondary)
                        Spacer()
                    }
                    if editQuotaEnabled {
                        HStack {
                            Text(Localized.quotaGB).font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                            TextField(Localized.quotaPlaceholder, text: $editQuotaValue)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                HStack(spacing: 8) {
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
                        var updated = profile
                        updated.name = editName
                        if editQuotaEnabled {
                            updated.quotaGB = Double(editQuotaValue.replacingOccurrences(of: ",", with: "."))
                        } else {
                            updated.quotaGB = nil
                        }
                        ProfileManager.shared.saveProfile(updated)
                        onProfilesChanged()
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
            .frame(maxHeight: .infinity)
            .frame(width: 280)

            if confirmDelete {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text(Localized.confirm).font(.headline)
                    Text(Localized.profileDeleteConfirm)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
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
                .padding(20)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 10)
            }

            if confirmDataReset {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text(Localized.confirm).font(.headline)
                    Text(Localized.profileResetConfirm)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
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
                .padding(20)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(10)
                .shadow(radius: 10)
            }
        }
        .frame(width: 280, height: 220)
    }
}
