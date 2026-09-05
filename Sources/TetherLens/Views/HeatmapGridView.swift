import SwiftUI

struct HeatmapGridView: View {
  let sessions: [Session]

  @State private var selectedDay: Int?
  @State private var selectedHour: Int?

  private struct CellData {
    let totalMinutes: Int
    let count: Int
  }

  private var gridData: [[CellData]] {
    var data = Array(repeating: Array(repeating: CellData(totalMinutes: 0, count: 0), count: 24), count: 7)
    let calendar = Calendar.current
    for session in sessions {
      guard let end = session.endTime else { continue }
      let startHour = calendar.component(.hour, from: session.startTime)
      let weekday = calendar.component(.weekday, from: session.startTime) - 1
      let duration = end.timeIntervalSince(session.startTime)
      let minutes = Int(duration / 60)
      let existing = data[weekday][startHour]
      data[weekday][startHour] = CellData(totalMinutes: existing.totalMinutes + minutes, count: existing.count + 1)
    }
    return data
  }

@Environment(\.colorScheme) private var colorScheme

  private func colorForMinutes(_ minutes: Int) -> Color {
    let isDark = colorScheme == .dark
    switch minutes {
    case 0: return isDark ? Color.white.opacity(0.08) : Color.gray.opacity(0.12)
    case 1..<15: return isDark ? Color.white.opacity(0.2) : Color.gray.opacity(0.25)
    case 15..<30: return isDark ? Color.blue.opacity(0.4) : Color.blue.opacity(0.35)
    case 30..<45: return isDark ? Color.blue.opacity(0.7) : Color.blue.opacity(0.6)
    default: return isDark ? Color.blue.opacity(0.9) : Color.blue
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      headerView
      gridView
      legendView
    }
    .padding(.horizontal, TLSpace.xl)
  }

  private var headerView: some View {
    VStack(spacing: TLSpace.xs) {
      Text(Localized.heatmapTitle)
        .font(TLFont.caption.bold())
        .foregroundColor(TLPalette.textSecondary)
        .padding(.top, TLSpace.md)

      if let day = selectedDay, let hour = selectedHour {
        let data = gridData[day][hour]
        Text(Localized.string("\(data.totalMinutes)분 (\(data.count)회)", "\(data.totalMinutes)min (\(data.count) times)"))
          .font(TLFont.caption2)
          .foregroundColor(TLPalette.textPrimary)
          .padding(.bottom, TLSpace.xs)
      } else {
        Text(Localized.dailyHotspotTime)
          .font(TLFont.caption2)
          .foregroundColor(TLPalette.textSecondary)
          .padding(.bottom, TLSpace.xs)
      }
    }
  }

  private var gridView: some View {
    GeometryReader { geo in
        // 가용폭에 맞춰 셀 너비 자동 조정 (최소 12) — 가로 스크롤 불필요
        let cellWidth = max((geo.size.width - 28 - 23 * 2 - TLSpace.md * 2) / 24, 12)
        gridContent(cellWidth: cellWidth)
            .frame(maxWidth: .infinity)
    }
    .frame(height: 170)
  }

  private func gridContent(cellWidth: CGFloat) -> some View {
    VStack(spacing: 2) {
      HStack(spacing: 2) {
        Text("")
          .frame(width: 28)
        ForEach(0..<24, id: \.self) { hour in
          Text("\(hour)")
            .font(TLFont.badge)
            .foregroundColor(TLPalette.textSecondary)
            .frame(width: cellWidth)
        }
      }
      ForEach(0..<7, id: \.self) { day in
        HStack(spacing: 2) {
          Text(Localized.dayLabels[day])
            .font(TLFont.badge)
            .foregroundColor(TLPalette.textSecondary)
            .frame(width: 28, alignment: .leading)
          ForEach(0..<24, id: \.self) { hour in
            let data = gridData[day][hour]
            RoundedRectangle(cornerRadius: 4)
              .fill(colorForMinutes(data.totalMinutes))
              .frame(width: cellWidth, height: 18)
              .overlay(selectedDay == day && selectedHour == hour ? RoundedRectangle(cornerRadius: 4).stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1) : nil)
              .onHover { hovering in
                if hovering {
                  select(day: day, hour: hour)
                }
              }
              .onTapGesture {
                select(day: day, hour: hour)
              }
              .focusable()
              .onKeyPress(.return) {
                select(day: day, hour: hour)
                return .handled
              }
              .accessibilityLabel(cellAccessibilityLabel(day: day, hour: hour, data: data))
          }
        }
      }
    }
    .padding(.horizontal, TLSpace.md)
  }

  private func select(day: Int, hour: Int) {
    selectedDay = day
    selectedHour = hour
  }

  private func cellAccessibilityLabel(day: Int, hour: Int, data: CellData) -> String {
    let dayLabel = Localized.dayLabels.indices.contains(day) ? Localized.dayLabels[day] : "\(day)"
    let time = String(format: Localized.string("%d시 %d분 (%d회)", "%d:00 %d min (%d times)"), hour, data.totalMinutes, data.count)
    return "\(dayLabel) \(time)"
  }

  private var legendView: some View {
    HStack(spacing: TLSpace.md) {
      Text(Localized.string("0분", "0min"))
        .font(TLFont.badge)
        .foregroundColor(TLPalette.textSecondary)
      legendSwatch(colorForMinutes(0))
      legendSwatch(colorForMinutes(7))
      legendSwatch(colorForMinutes(22))
      legendSwatch(colorForMinutes(37))
      legendSwatch(colorForMinutes(60))
      Text(Localized.string("60분", "60min"))
        .font(TLFont.badge)
        .foregroundColor(TLPalette.textSecondary)
    }
    .padding(.vertical, TLSpace.sm)
  }

  private func legendSwatch(_ color: Color) -> some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(color)
      .frame(width: 12, height: 12)
  }
}
