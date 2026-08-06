import SwiftUI

struct MovementTimelineView: View {
  let sessions: [Session]
  let onSelect: (Session) -> Void

  private var timeline: [TimelineItem] {
    let profileIds = Set(sessions.compactMap(\.profileId))
    var events: [TimelineItem] = []
    let pm = ProfileManager.shared
    for pid in profileIds {
      let days = daysFor(sessions: sessions, profileId: pid)
      events += pm.getMovementTimeline(profileId: pid, days: days).map { item in
        TimelineItem(
          timestamp: item.timestamp,
          kind: item.kind,
          latitude: item.latitude,
          longitude: item.longitude,
          locationSource: item.locationSource,
          ipAddress: item.ipAddress,
          session: sessions.first { $0.profileId == pid && $0.startTime == item.timestamp && item.kind == .session }
        )
      }
    }
    return events.sorted { $0.timestamp > $1.timestamp }
  }

  private func daysFor(sessions: [Session], profileId: UUID) -> Int {
    guard let oldest = sessions.filter({ $0.profileId == profileId }).map(\.startTime).min(),
          let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day else { return 30 }
    return max(days, 1)
  }

  var body: some View {
    Group {
      if sessions.isEmpty {
        Spacer()
        Text(Localized.noSessionData)
          .foregroundColor(TLPalette.textSecondary)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(timeline) { item in
              MovementRow(item: item) {
                guard let session = item.session,
                      let lat = item.latitude, let lng = item.longitude else { return }
                onSelect(session)
              }
              Divider()
            }
          }
          .padding(.horizontal, TLSpace.xl)
        }
      }
    }
  }
}

private struct TimelineItem: Identifiable {
  let id = UUID()
  let timestamp: Date
  let kind: ProfileManager.MovementEvent.Kind
  let latitude: Double?
  let longitude: Double?
  let locationSource: String?
  let ipAddress: String?
  let session: Session?
}

private struct MovementRow: View {
  let item: TimelineItem
  let onTap: () -> Void

  private var timeString: String {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMMd HHmm")
    return f.string(from: item.timestamp)
  }

  private var kindLabel: String {
    switch item.kind {
    case .session: return Localized.string("이동", "Move")
    case .ipChange: return Localized.string("IP 변경", "IP change")
    }
  }

  private var kindColor: Color {
    switch item.kind {
    case .session: return TLPalette.download
    case .ipChange: return TLPalette.upload
    }
  }

  private var sourceLabel: String {
    switch item.locationSource {
    case "gps": return Localized.string("GPS", "GPS")
    case "ip": return Localized.string("IP", "IP")
    default: return ""
    }
  }

  private var coordString: String {
    guard let lat = item.latitude, let lng = item.longitude else { return "" }
    return String(format: "%.4f, %.4f", lat, lng)
  }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: TLSpace.md) {
        Circle()
          .fill(kindColor)
          .frame(width: 8, height: 8)

        VStack(alignment: .leading, spacing: 2) {
          Text(timeString)
            .font(TLFont.caption.monospacedDigit().bold())
          HStack(spacing: TLSpace.xs) {
            Text(kindLabel)
              .font(TLFont.caption2)
              .foregroundColor(kindColor)
            if !sourceLabel.isEmpty {
              Text("· \(sourceLabel)")
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
            }
            if let ip = item.ipAddress {
              Text("· \(ip)")
                .font(TLFont.caption2.monospacedDigit())
                .foregroundColor(TLPalette.textSecondary)
            }
          }
          if !coordString.isEmpty {
            Text(coordString)
              .font(TLFont.caption2.monospacedDigit())
              .foregroundColor(TLPalette.copyHint)
          }
        }

        Spacer()

        Image(systemName: "arrow.turn.up.right")
          .font(TLFont.caption)
          .foregroundColor(TLPalette.copyHint)
      }
      .contentShape(Rectangle())
      .padding(.vertical, TLSpace.sm)
    }
    .buttonStyle(.plain)
  }
}
