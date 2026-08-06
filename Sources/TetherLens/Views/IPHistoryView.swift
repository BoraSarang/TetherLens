import SwiftUI

struct IPHistoryView: View {
    let profileId: UUID
    let onClose: () -> Void
    @State private var logs: [IPLog] = []

    var body: some View {
        VStack(spacing: TLSpace.xl) {
            Text(Localized.ipHistory)
                .font(TLFont.headline)
                .padding(.top, TLSpace.xxl)

            if logs.isEmpty {
                Spacer()
                Text(Localized.noIPHistory)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                List(logs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.ipAddress)
                                .font(TLFont.body)
                            HStack(spacing: TLSpace.xs) {
                                if let country = log.country {
                                    Text(country)
                                        .font(TLFont.caption2)
                                        .foregroundColor(TLPalette.textSecondary)
                                }
                                Text(Localized.firstSeen(dateString(log.firstSeenAt)))
                                    .font(TLFont.caption2)
                                    .foregroundColor(TLPalette.textSecondary)
                            }
                        }
                        Spacer()
                        Text(Localized.lastSeen(relativeTimeString(log.lastSeenAt)))
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textSecondary)
                    }
                }
                .listStyle(.plain)
            }

            Button(Localized.close) { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, TLSpace.xxl)
        }
        .frame(width: TLSize.sheetCompact, height: 300)
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
