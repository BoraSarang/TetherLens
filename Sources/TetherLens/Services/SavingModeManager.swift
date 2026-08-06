import Foundation

final class SavingModeManager: @unchecked Sendable {
    static let shared = SavingModeManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "savingMode": false,
            "savingModeAuto": true
        ])
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("com.apple.system.lowPowerModeDidChange"),
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .init("powerStateChanged"), object: nil)
            }
        }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: "savingMode") }
        set {
            defaults.set(newValue, forKey: "savingMode")
            NotificationCenter.default.post(name: .init("savingModeChanged"), object: nil)
        }
    }

    var autoActivate: Bool {
        get { defaults.bool(forKey: "savingModeAuto") }
        set { defaults.set(newValue, forKey: "savingModeAuto") }
    }

    let autoActivateThreshold: Double = 0.8

    var greenThreshold: Double { isEnabled ? 0.4 : 0.6 }
    var orangeThreshold: Double { isEnabled ? 0.65 : 0.85 }

    func shouldAutoActivate(used: Double, quota: Double) -> Bool {
        guard autoActivate, quota > 0 else { return false }
        return used / quota >= autoActivateThreshold
    }

    var isLowPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
