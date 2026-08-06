import SwiftUI

struct NotificationListView: View {
    @ObservedObject private var manager = NotificationManager.shared
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: TLSpace.xl) {
            HStack {
                Text(Localized.notificationListTitle)
                    .font(TLFont.headline)
                Spacer()
                if !manager.notifications.isEmpty {
                    Button(Localized.clearAll) { manager.clearAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, TLSpace.xxl)
            .padding(.top, TLSpace.xxl)

            Divider()

            if manager.notifications.isEmpty {
                Spacer()
                Text(Localized.noNotifications)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                List {
                    ForEach(manager.notifications) { note in
                        HStack(spacing: TLSpace.md) {
                            Image(systemName: notificationIcon(for: note.type))
                                .foregroundColor(notificationColor(for: note.type))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.message)
                                    .font(TLFont.caption)
                                Text(note.timestamp, style: .time)
                                    .font(TLFont.caption2)
                                    .foregroundColor(TLPalette.textSecondary)
                            }
                        }
                        .padding(.vertical, TLSpace.xs)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            Button(Localized.close) { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, TLSpace.xl)
        }
        .frame(width: TLSize.sheetCompact, height: 320)
    }

    private func notificationIcon(for type: AppNotification.NotificationType) -> String {
        switch type {
        case .quotaExceeded, .pingCritical: return "xmark.circle.fill"
        case .pingRecovery, .connectionRestored: return "checkmark.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private func notificationColor(for type: AppNotification.NotificationType) -> Color {
        switch type {
        case .quotaExceeded, .pingCritical: return TLPalette.danger
        case .pingWarning: return TLPalette.upload
        case .pingRecovery: return TLPalette.success
        case .connectionLost: return TLPalette.download
        case .connectionRestored: return TLPalette.success
        case .quotaWarning: return TLPalette.upload
        }
    }
}
