import SwiftUI

struct IPHistoryView: View {
    let profileId: UUID
    let onClose: () -> Void
    @State private var logs: [IPLog] = []

    var body: some View {
        VStack(spacing: 12) {
            Text(Localized.ipHistory)
                .font(.headline)
                .padding(.top, 16)

            if logs.isEmpty {
                Spacer()
                Text(Localized.noIPHistory)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(logs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.ipAddress)
                                .font(.body)
                            HStack(spacing: 4) {
                                if let country = log.country {
                                    Text(country)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(Localized.firstSeen(dateString(log.firstSeenAt)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(Localized.lastSeen(relativeTimeString(log.lastSeenAt)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)
            }

            Button(Localized.close) { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, 16)
        }
        .frame(width: 280, height: 300)
        .onAppear {
            logs = ProfileManager.shared.getIPLogs(profileId: profileId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ipChanged"))) { _ in
            logs = ProfileManager.shared.getIPLogs(profileId: profileId)
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }

    private func relativeTimeString(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return Localized.justNow }
        if interval < 3600 { return Localized.minutesAgo(Int(interval / 60)) }
        if interval < 86400 { return Localized.hoursAgo(Int(interval / 3600)) }
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: date)
    }
}
