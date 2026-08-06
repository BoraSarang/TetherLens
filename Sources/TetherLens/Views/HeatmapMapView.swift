import SwiftUI
import MapKit

struct HeatmapMapView: View {
  let sessions: [Session]
  var focusCoordinate: CLLocationCoordinate2D?

  private var markedSessions: [(session: Session, lat: Double, lng: Double)] {
    sessions.compactMap { s in
      guard let lat = s.latitude, let lng = s.longitude else { return nil }
      return (s, lat, lng)
    }
  }

  private var lastMarker: (session: Session, lat: Double, lng: Double)? {
    markedSessions.max { $0.session.startTime < $1.session.startTime }
  }

  private var latestRegion: MKCoordinateRegion? {
    guard let last = lastMarker else { return nil }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lng),
      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
  }

  private func sourceLabel(_ source: String?) -> String {
    switch source {
    case "gps": return Localized.string("GPS", "GPS")
    case "ip": return Localized.string("IP", "IP")
    default: return Localized.string("알 수 없음", "Unknown")
    }
  }

  private func sourceColor(_ source: String?) -> Color {
    switch source {
    case "gps": return TLPalette.success
    case "ip": return TLPalette.accent
    default: return TLPalette.textSecondary
    }
  }

  @State private var cameraPosition: MapCameraPosition = .automatic

  /// 동일 좌표(정밀도 3자리)로 그룹핑한 클러스터. 세션 수 > 1이면 숫자 배지.
  private var clusters: [(lat: Double, lng: Double, sessions: [Session])] {
    var groups: [String: (lat: Double, lng: Double, sessions: [Session])] = [:]
    for item in markedSessions {
      let keyLat = String(format: "%.3f", item.lat)
      let keyLng = String(format: "%.3f", item.lng)
      let key = "\(keyLat),\(keyLng)"
      if var g = groups[key] {
        g.sessions.append(item.session)
        groups[key] = g
      } else {
        groups[key] = (item.lat, item.lng, [item.session])
      }
    }
    return groups.values.map { ($0.lat, $0.lng, $0.sessions) }
      .sorted { $0.sessions.first?.startTime ?? .distantPast < $1.sessions.first?.startTime ?? .distantPast }
  }

  private var latestCluster: (lat: Double, lng: Double, sessions: [Session])? {
    clusters.last
  }

  var body: some View {
    Group {
      if markedSessions.isEmpty {
        VStack(spacing: TLSpace.md) {
          Spacer()
          Image(systemName: "map")
            .font(.largeTitle)
            .foregroundColor(TLPalette.textSecondary)
          Text(Localized.string("위치 데이터가 없습니다", "No location data"))
            .font(TLFont.caption)
            .foregroundColor(TLPalette.textSecondary)
          Spacer()
        }
      } else {
        Map(position: $cameraPosition) {
          ForEach(Array(clusters.enumerated()), id: \.offset) { _, cluster in
            let isLatest = latestCluster.map { $0.lat == cluster.lat && $0.lng == cluster.lng } ?? false
            let isCluster = cluster.sessions.count > 1
            let coordinate = CLLocationCoordinate2D(latitude: cluster.lat, longitude: cluster.lng)
            Annotation(sourceLabel(cluster.sessions.last?.locationSource), coordinate: coordinate) {
              VStack(spacing: 2) {
                ZStack {
                  if isLatest {
                    Circle()
                      .fill(Color.red.opacity(0.25))
                      .frame(width: 44, height: 44)
                  }
                  Circle()
                    .fill(markerColor(cluster.sessions.last?.locationSource))
                    .frame(width: isCluster ? 30 : 14, height: isCluster ? 30 : 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 4)
                  if isCluster {
                    Text("\(cluster.sessions.count)")
                      .font(TLFont.smallBold)
                      .foregroundColor(.white)
                  }
                }
                if cluster.sessions.last?.locationSource != nil {
                  HStack(spacing: 2) {
                    Circle()
                      .fill(sourceColor(cluster.sessions.last?.locationSource))
                      .frame(width: 6, height: 6)
                    Text(sourceLabel(cluster.sessions.last?.locationSource))
                      .font(TLFont.small)
                      .foregroundColor(TLPalette.textSecondary)
                  }
                }
              }
            }
          }
        }
        .padding(.horizontal, TLSpace.xl)
        .onAppear {
          if let latest = latestCluster {
            cameraPosition = .region(MKCoordinateRegion(
              center: CLLocationCoordinate2D(latitude: latest.lat, longitude: latest.lng),
              span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
          }
        }
        .onChange(of: focusCoordinate?.latitude) { _ in focusOnFocusCoordinate() }
        .onChange(of: focusCoordinate?.longitude) { _ in focusOnFocusCoordinate() }
      }
    }
  }

  private func focusOnFocusCoordinate() {
    guard let focusCoordinate else { return }
    cameraPosition = .region(MKCoordinateRegion(
      center: focusCoordinate,
      span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))
  }

  private func markerColor(_ source: String?) -> Color {
    switch source {
    case "gps": return TLPalette.download
    case "ip": return TLPalette.upload
    default: return TLPalette.accent
    }
  }
}
