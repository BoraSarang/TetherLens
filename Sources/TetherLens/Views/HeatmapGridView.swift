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

  private func colorForMinutes(_ minutes: Int) -> Color {
    switch minutes {
    case 0: return Color.gray.opacity(0.12)
    case 1..<15: return Color.gray.opacity(0.25)
    case 15..<30: return Color.blue.opacity(0.35)
    case 30..<45: return Color.blue.opacity(0.6)
    default: return Color.blue
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      headerView
      ScrollView(.horizontal, showsIndicators: false) {
        gridView
      }
      legendView
    }
    .padding(.horizontal, 12)
  }

  private var headerView: some View {
    VStack(spacing: 4) {
      Text(Localized.heatmapTitle)
        .font(.caption.bold())
        .foregroundColor(.secondary)
        .padding(.top, 8)

      if let day = selectedDay, let hour = selectedHour {
        let data = gridData[day][hour]
        Text("\(Localized.dayLabels[day]) \(hour):00 — \(data.totalMinutes)분 (\(data.count)회)")
          .font(.caption2)
          .foregroundColor(.primary)
          .padding(.bottom, 4)
      } else {
        Text(Localized.dailyHotspotTime)
          .font(.caption2)
          .foregroundColor(.secondary)
          .padding(.bottom, 4)
      }
    }
  }

  private var gridView: some View {
    VStack(spacing: 2) {
      HStack(spacing: 2) {
        Text("")
          .frame(width: 28)
        ForEach(0..<24, id: \.self) { hour in
          Text("\(hour)")
            .font(.system(size: 7))
            .foregroundColor(.secondary)
            .frame(width: 18)
        }
      }
      ForEach(0..<7, id: \.self) { day in
        HStack(spacing: 2) {
          Text(Localized.dayLabels[day])
            .font(.system(size: 8))
            .foregroundColor(.secondary)
            .frame(width: 28, alignment: .leading)
          ForEach(0..<24, id: \.self) { hour in
            let data = gridData[day][hour]
            RoundedRectangle(cornerRadius: 3)
              .fill(colorForMinutes(data.totalMinutes))
              .frame(width: 18, height: 18)
              .overlay(selectedDay == day && selectedHour == hour ? RoundedRectangle(cornerRadius: 3).stroke(Color.white, lineWidth: 1) : nil)
              .onHover { hovering in
                if hovering {
                  selectedDay = day
                  selectedHour = hour
                }
              }
          }
        }
      }
    }
    .padding(.horizontal, 8)
  }

  private var legendView: some View {
    HStack(spacing: 8) {
      Text(Localized.string("0분", "0min"))
        .font(.system(size: 8))
        .foregroundColor(.secondary)
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.gray.opacity(0.25))
        .frame(width: 12, height: 12)
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.blue.opacity(0.35))
        .frame(width: 12, height: 12)
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.blue.opacity(0.6))
        .frame(width: 12, height: 12)
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.blue)
        .frame(width: 12, height: 12)
      Text(Localized.string("60분", "60min"))
        .font(.system(size: 8))
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 6)
  }
}
