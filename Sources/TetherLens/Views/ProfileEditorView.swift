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
        ZStack {
            VStack(spacing: 16) {
                Text("프로필 편집")
                    .font(.headline)
                    .padding(.top, 16)

                VStack(spacing: 10) {
                    HStack {
                        Text("이름:").font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                        TextField("이름", text: $editName)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("SSID:").font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                        Text(profile.ssid).font(.body).foregroundColor(.primary)
                        Spacer()
                    }
                    HStack {
                        Text("할당량:").font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                        Toggle(isOn: $editQuotaEnabled) { EmptyView() }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        Text("사용").font(.body).foregroundColor(.secondary)
                        Spacer()
                    }
                    if editQuotaEnabled {
                        HStack {
                            Text("GB:").font(.body).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                            TextField("예: 3.0", text: $editQuotaValue)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button("삭제", role: .destructive) {
                        confirmDelete = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button("취소") { onClose() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("저장") {
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
                .padding(.bottom, 16)
            }
            .frame(width: 280)

            if confirmDelete {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("확인").font(.headline)
                    Text("통계 정보 등 모든 데이터가 삭제됩니다.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button("취소") { confirmDelete = false }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("삭제", role: .destructive) {
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
        }
        .frame(width: 280, height: 260)
    }
}
