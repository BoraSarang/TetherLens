import SwiftUI

struct HeatmapView: View {
  let sessions: [Session]

  @State private var selectedTab = 0

  var body: some View {
    VStack(spacing: 0) {
      Picker("", selection: $selectedTab) {
        Text(Localized.gridView).tag(0)
        Text(Localized.mapView).tag(1)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)

      Divider()

      if selectedTab == 0 {
        HeatmapGridView(sessions: sessions)
      } else {
        HeatmapMapView(sessions: sessions)
      }

      Spacer()
    }
  }
}
