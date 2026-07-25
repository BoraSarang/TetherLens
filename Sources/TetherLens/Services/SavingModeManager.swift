import Foundation

final class SavingModeManager: @unchecked Sendable {
    static let shared = SavingModeManager()

    private let defaults = UserDefaults.standard

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

    private init() {
        defaults.register(defaults: [
            "savingMode": false,
            "savingModeAuto": true
        ])
    }
}
