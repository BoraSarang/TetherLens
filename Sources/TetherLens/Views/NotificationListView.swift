import SwiftUI

struct NotificationListView: View {
    @ObservedObject private var manager = NotificationManager.shared
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(Localized.notificationListTitle)
                    .font(.headline)
                Spacer()
                if !manager.notifications.isEmpty {
                    Button(Localized.clearAll) { manager.clearAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider()

            if manager.notifications.isEmpty {
                Spacer()
                Text(Localized.noNotifications)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(manager.notifications) { note in
                        HStack(spacing: 8) {
                            Image(systemName: notificationIcon(for: note.type))
                                .foregroundColor(notificationColor(for: note.type))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.message)
                                    .font(.caption)
                                Text(note.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            Button(Localized.close) { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, 12)
        }
        .frame(width: 280, height: 320)
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
        case .quotaExceeded, .pingCritical: return .red
        case .pingWarning: return .orange
        case .pingRecovery: return .green
        case .connectionLost: return .blue
        case .connectionRestored: return .green
        case .quotaWarning: return .orange
        }
    }
}
