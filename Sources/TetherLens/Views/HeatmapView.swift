import SwiftUI
import MapKit

struct HeatmapView: View {
  let sessions: [Session]

  @State private var selectedTab = 0
  @State private var focusCoordinate: CLLocationCoordinate2D?

  private var locatedSessions: [Session] {
    sessions.filter { $0.latitude != nil && $0.longitude != nil }
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("", selection: $selectedTab) {
        Text(Localized.gridView).tag(0)
        Text(Localized.mapView).tag(1)
        Text(Localized.movementTitle).tag(2)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)

      Divider()

      if selectedTab == 0 {
        HeatmapGridView(sessions: locatedSessions)
      } else if selectedTab == 1 {
        HeatmapMapView(sessions: locatedSessions, focusCoordinate: focusCoordinate)
      } else {
        MovementTimelineView(
          sessions: locatedSessions,
          onSelect: { session in
            guard let lat = session.latitude, let lng = session.longitude else { return }
            focusCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            selectedTab = 1
          }
        )
      }

    }
  }
}
