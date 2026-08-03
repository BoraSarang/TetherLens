import SwiftUI
import MapKit

struct HeatmapMapView: View {
  let sessions: [Session]

  private var markedSessions: [(session: Session, lat: Double, lng: Double)] {
    sessions.compactMap { s in
      guard let lat = s.latitude, let lng = s.longitude else { return nil }
      return (s, lat, lng)
    }
  }

  private var lastMarker: (session: Session, lat: Double, lng: Double)? {
    markedSessions.max { $0.session.startTime < $1.session.startTime }
  }

  private var region: MKCoordinateRegion? {
    let coords = markedSessions.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    guard !coords.isEmpty else { return nil }
    let minLat = coords.map(\.latitude).min()!
    let maxLat = coords.map(\.latitude).max()!
    let minLng = coords.map(\.longitude).min()!
    let maxLng = coords.map(\.longitude).max()!
    let spanLat = max(maxLat - minLat, 0.05) * 1.5
    let spanLng = max(maxLng - minLng, 0.05) * 1.5
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
      span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
    )
  }

  private var latestRegion: MKCoordinateRegion? {
    guard let last = lastMarker else { return nil }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lng),
      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
  }

  private func timeLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
  }

  @State private var cameraPosition: MapCameraPosition = .automatic

  var body: some View {
    Group {
      if markedSessions.isEmpty {
        VStack(spacing: 8) {
          Spacer()
          Image(systemName: "map")
            .font(.largeTitle)
            .foregroundColor(.secondary)
          Text(Localized.string("위치 데이터가 없습니다", "No location data"))
            .font(.caption)
            .foregroundColor(.secondary)
          Spacer()
        }
      } else {
        Map(initialPosition: latestRegion.map { .region($0) } ?? .automatic) {
          ForEach(Array(markedSessions.enumerated()), id: \.offset) { _, item in
            if let last = lastMarker, last.lat == item.lat, last.lng == item.lng, last.session.startTime == item.session.startTime {
              Annotation(Localized.string("최근 위치", "Latest"), coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lng)) {
                ZStack {
                  Circle()
                    .fill(Color.red.opacity(0.25))
                    .frame(width: 44, height: 44)
                  Circle()
                    .fill(Color.red)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .red.opacity(0.7), radius: 6)
                }
              }
            } else {
              Marker(timeLabel(item.session.startTime),
                     coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lng))
            }
          }
        }
        .padding(.horizontal, 12)
      }
    }
  }
}
