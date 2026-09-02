import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var locationManager: LocationManager?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager = LocationManager()

        NSApp.setActivationPolicy(.accessory)

        _ = UpdaterManager.shared

        menuBarManager = MenuBarManager(locationManager: locationManager!)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.menuBarManager?.startMonitoring()
            if SettingsManager.shared.floatingShowAtLaunch {
                FloatingWindowController.shared.show()
            }
        }

        showOnboardingIfNeeded()
    }

    private func showOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "hasShownOnboarding") else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = Localized.string("TetherLens", "TetherLens")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: OnboardingView {
            UserDefaults.standard.set(true, forKey: "hasShownOnboarding")
            window.close()
            self.onboardingWindow = nil
            self.locationManager?.requestAuthorization()
        })
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
