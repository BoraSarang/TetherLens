import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var locationManager: LocationManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager = LocationManager()
        locationManager?.requestAuthorization()

        NSApp.setActivationPolicy(.accessory)

        _ = UpdaterManager.shared

        menuBarManager = MenuBarManager(locationManager: locationManager!)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.menuBarManager?.startMonitoring()
        }
    }
}
