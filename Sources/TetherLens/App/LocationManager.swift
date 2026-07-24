import CoreLocation
import AppKit

@MainActor
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    var onAuthorizationChange: ((Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
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

    func requestAuthorizationAsync() async -> Bool {
        guard !isAuthorized else { return true }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let authorized = isAuthorized
            authorizationContinuation?.resume(returning: authorized)
            authorizationContinuation = nil
            onAuthorizationChange?(authorized)
        }
    }
}
