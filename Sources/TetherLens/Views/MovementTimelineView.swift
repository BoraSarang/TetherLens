import SwiftUI

struct MovementTimelineView: View {
  let sessions: [Session]
  let onSelect: (Session) -> Void

  @State private var timeline: [TimelineItem] = []

  fileprivate static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMMd HHmm")
    return f
  }()

  private static func buildTimeline(sessions: [Session]) -> [TimelineItem] {
    let profileIds = Set(sessions.compactMap(\.profileId))
    var events: [TimelineItem] = []
    let pm = ProfileManager.shared
    for pid in profileIds {
      let days = daysFor(sessions: sessions, profileId: pid)
      events += pm.getMovementTimeline(profileId: pid, days: days).map { item in
        TimelineItem(
          profileId: pid,
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
    let sorted = events.sorted { $0.timestamp > $1.timestamp }
    // 정렬이 끝난 뒤 출현 순번을 붙인다. 같은 입력 → 같은 ID 이라
    // 타임라인을 다시 계산해도 행 ID 가 흔들리지 않는다.
    var seen: [String: Int] = [:]
    return sorted.map { item in
      let n = seen[item.stableKey, default: 0]
      seen[item.stableKey] = n + 1
      return item.identified(occurrence: n)
    }
  }

  private static func daysFor(sessions: [Session], profileId: UUID) -> Int {
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
    .onAppear {
      timeline = Self.buildTimeline(sessions: sessions)
    }
    .onChange(of: sessions) { _, newValue in
      timeline = Self.buildTimeline(sessions: newValue)
    }
  }
}

private struct TimelineItem: Identifiable {
  /// 결정론적 행 ID.
  ///
  /// 예전엔 `let id = UUID()` 였는데, 타임라인을 다시 계산할 때마다 모든 ID 가 새로
  /// 만들어져 SwiftUI 가 전 행을 폐기하고 다시 만들었다 (T-250 #8).
  /// 세션 목록이 바뀔 때 애니메이션·선택 상태가 통째로 사라지는 원인이었다.
  var id: String = ""
  let profileId: UUID
  let timestamp: Date
  let kind: ProfileManager.MovementEvent.Kind
  let latitude: Double?
  let longitude: Double?
  let locationSource: String?
  let ipAddress: String?
  let session: Session?

  /// 프로필 + 발생시각 + 종류 + IP + 출처 조합. 같은 입력에서 항상 같은 값이다.
  /// (`Kind` 는 rawValue 가 없는 단순 enum 이라 `String(describing:)` 로 고정 문자열을 얻는다)
  fileprivate var stableKey: String {
    "\(profileId.uuidString)-\(timestamp.timeIntervalSince1970)-\(String(describing: kind))"
      + "-\(ipAddress ?? "-")-\(locationSource ?? "-")"
  }

  /// 같은 조합이 실제로 겹칠 수 있어 출현 순번으로 ID 를 유일하게 만든다.
  fileprivate func identified(occurrence: Int) -> TimelineItem {
    var copy = self
    copy.id = occurrence == 0 ? stableKey : "\(stableKey)#\(occurrence)"
    return copy
  }
}

private struct MovementRow: View {
  let item: TimelineItem
  let onTap: () -> Void

  private var timeString: String {
    MovementTimelineView.timeFormatter.string(from: item.timestamp)
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
