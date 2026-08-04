import CoreLocation
import CoreWLAN
import AppKit
import os.log

@MainActor
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    var onAuthorizationChange: ((Bool) -> Void)?
    private(set) var lastLatitude: Double?
    private(set) var lastLongitude: Double?
    private var locationTimeoutTask: Task<Void, Never>?

    private static let latKey = "last_latitude"
    private static let lngKey = "last_longitude"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        lastLatitude = UserDefaults.standard.object(forKey: Self.latKey) as? Double
        lastLongitude = UserDefaults.standard.object(forKey: Self.lngKey) as? Double
        if lastLatitude != nil {
            DebugLogger.shared.system("Location", "복원된 위치: \(lastLatitude!),\(lastLongitude!)")
        }
        if isAuthorized {
            startUpdating()
        }
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    static var systemLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    var isAuthorized: Bool {
        manager.authorizationStatus == .authorized
            || manager.authorizationStatus == .authorizedAlways
    }

    var diagnostics: [String] {
        var result: [String] = []
        result.append("System Location: \(Self.systemLocationServicesEnabled ? "ON" : "OFF")")
        result.append("App Authorization: \(authorizationStatusString)")
        let wifiInterface = CWWiFiClient.shared().interface()
        result.append("Wi-Fi: \(wifiInterface != nil ? "Present" : "Not Found")")
        if let iface = wifiInterface {
            result.append("SSID: \(iface.ssid() ?? "-")")
        }
        result.append("Cached: \(lastLatitude != nil ? "\(lastLatitude!),\(lastLongitude!)" : "None")")
        return result
    }

    private var authorizationStatusString: String {
        switch manager.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorized: return "When In Use"
        @unknown default: return "Unknown"
        }
    }

    private func startUpdating() {
        manager.startUpdatingLocation()
        DebugLogger.shared.system("Location", "연속 위치 업데이트 시작")
        locationTimeoutTask?.cancel()
        locationTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            if self.lastLatitude == nil {
                DebugLogger.shared.warn("Location", "60초 내 위치 미획득, CoreLocation 포기")
            }
        }
    }

    func requestAuthorizationAsync() async -> Bool {
        guard !isAuthorized else { return true }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManager(_ locManager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLatitude = loc.coordinate.latitude
            self.lastLongitude = loc.coordinate.longitude
            UserDefaults.standard.set(loc.coordinate.latitude, forKey: Self.latKey)
            UserDefaults.standard.set(loc.coordinate.longitude, forKey: Self.lngKey)
            locationTimeoutTask?.cancel()
            DebugLogger.shared.system("Location", "위치 획득: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        }
    }

    nonisolated func locationManager(_ locManager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        Task { @MainActor in
            if nsError.code == CLError.locationUnknown.rawValue {
                DebugLogger.shared.system("Location", "CoreLocation 알 수 없는 오류 - IP 기반 fallback")
            } else {
                DebugLogger.shared.warn("Location", "위치 오류: \(error.localizedDescription) (code=\(nsError.code))")
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ locManager: CLLocationManager) {
        let authorized = locManager.authorizationStatus == .authorized || locManager.authorizationStatus == .authorizedAlways
        Task { @MainActor in
            if authorized {
                DebugLogger.shared.system("Location", "권한 승인됨")
                self.startUpdating()
            } else {
                DebugLogger.shared.warn("Location", "권한 거부됨")
            }
            authorizationContinuation?.resume(returning: authorized)
            authorizationContinuation = nil
            onAuthorizationChange?(authorized)
        }
    }
}
