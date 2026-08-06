import SwiftUI

struct SessionTimelineView: View {
  let sessions: [Session]
  let profileName: String

  var body: some View {
    Group {
      if sessions.isEmpty {
        Spacer()
        Text(Localized.noSessionData)
          .foregroundColor(.secondary)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(sessions) { session in
              SessionRow(session: session)
              Divider()
            }
          }
          .padding(.horizontal, 12)
        }
      }
    }
  }
}

private struct SessionRow: View {
  let session: Session

  private var usage: (upload: Int64, download: Int64) {
    ProfileManager.shared.getSessionUsage(session: session)
  }

  private var ipAddress: String? {
    ProfileManager.shared.getIPForSession(session)?.ipAddress
  }

  private var durationString: String {
    guard let end = session.endTime else { return Localized.inProgress }
    let interval = end.timeIntervalSince(session.startTime)
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    let seconds = Int(interval) % 60
    if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
    return String(format: "%02d:%02d", minutes, seconds)
  }

  private var timeRangeString: String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    let start = f.string(from: session.startTime)
    guard let end = session.endTime else { return "\(start) → ..." }
    return "\(start) → \(f.string(from: end))"
  }

  private var usageString: String {
    let total = usage.upload + usage.download
    let b = Double(total)
    if b >= 1_000_000_000 { return String(format: "%.1f GB", b / 1_000_000_000) }
    if b >= 1_000_000 { return String(format: "%.0f MB", b / 1_000_000) }
    if b >= 1_000 { return String(format: "%.0f KB", b / 1_000) }
    return "\(total) B"
  }

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(session.endTime != nil ? Color.blue : Color.green)
        .frame(width: 8, height: 8)

      VStack(alignment: .leading, spacing: 2) {
        Text(timeRangeString)
          .font(.caption.monospacedDigit().bold())
        HStack(spacing: 4) {
          Text(durationString)
            .font(.caption2.monospacedDigit())
            .foregroundColor(.secondary)
          if let ip = ipAddress {
            Text("· \(ip)")
              .font(.caption2.monospacedDigit())
              .foregroundColor(.secondary)
          }
          if session.endTime != nil {
            Text(usageString)
              .font(.caption2.monospacedDigit())
              .foregroundColor(.orange)
          } else {
            Text(Localized.inProgress)
              .font(.caption2)
              .foregroundColor(.green)
          }
        }
      }

      Spacer()
    }
    .padding(.vertical, 6)
  }
}
