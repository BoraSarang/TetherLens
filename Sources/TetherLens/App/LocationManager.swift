import CoreLocation
import AppKit

@MainActor
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
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
            authorizationContinuation?.resume(returning: isAuthorized)
            authorizationContinuation = nil
        }
    }
}
