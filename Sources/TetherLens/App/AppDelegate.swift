import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var locationManager: LocationManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        locationManager = LocationManager()
        locationManager?.requestAuthorization()

        menuBarManager = MenuBarManager(locationManager: locationManager!)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.menuBarManager?.startMonitoring()
        }
    }
}
