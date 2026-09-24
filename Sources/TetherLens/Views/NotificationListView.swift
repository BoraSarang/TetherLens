import SwiftUI

struct NotificationListView: View {
    @ObservedObject private var manager = NotificationManager.shared

    private static let resolvedTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if manager.notifications.isEmpty {
                Spacer()
                Text(Localized.noNotifications)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                List {
                    ForEach(manager.notifications) { note in
                        notificationRow(note)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: TLSize.notificationsWindow.w, height: TLSize.notificationsWindow.h)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !manager.notifications.isEmpty {
                    Button(Localized.clearAll) { manager.clearAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private func notificationRow(_ note: AppNotification) -> some View {
        // 해소된 경고성 알림만 강도 낮춤 + 해소 표시. 복구/쿼타 알림은 기존 표시 유지.
        let isResolvedWarning = note.resolvedAt != nil && AppNotification.isWarningLike(note.type)
        return HStack(spacing: TLSpace.md) {
            Image(systemName: isResolvedWarning
                  ? "checkmark.circle"
                  : notificationIcon(for: note.type))
                .foregroundColor(notificationColor(for: note.type))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: TLSpace.xs) {
                    Text(note.message)
                        .font(TLFont.caption)
                    if isResolvedWarning {
                        Text(Localized.resolved)
                            .font(TLFont.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: TLRound.small)
                                    .stroke(TLPalette.success.opacity(0.6))
                            )
                            .foregroundColor(TLPalette.textSecondary)
                    }
                }
                HStack(spacing: TLSpace.xs) {
                    Text(note.timestamp, style: .time)
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.textSecondary)
                    if isResolvedWarning, let resolvedAt = note.resolvedAt {
                        Text("→ \(Self.resolvedTimeFormatter.string(from: resolvedAt))")
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textSecondary)
                    }
                }
            }
        }
        .padding(.vertical, TLSpace.xs)
        .opacity(isResolvedWarning ? 0.55 : 1.0)
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
