import Foundation
import UserNotifications
import Combine

@MainActor
final class AppBlockManager: ObservableObject {
    static let shared = AppBlockManager()

    private let defaults = UserDefaults.standard
    private let blockedKey = "blocked_apps"
    private var notified: Set<String> = []

    private init() {}

    var blockedApps: Set<String> {
        get {
            let raw = defaults.string(forKey: blockedKey) ?? ""
            return Set(raw.split(separator: ",").map(String.init))
        }
        set {
            defaults.set(newValue.sorted().joined(separator: ","), forKey: blockedKey)
            notified.removeAll()
            objectWillChange.send()
        }
    }

    func setBlocked(_ name: String, blocked: Bool) {
        var set = blockedApps
        if blocked {
            set.insert(name)
        } else {
            set.remove(name)
        }
        blockedApps = set
    }

    func isBlocked(_ name: String) -> Bool {
        blockedApps.contains(name)
    }

    func check(_ name: String, bytesIn: Int64, bytesOut: Int64) {
        guard isBlocked(name), bytesIn > 0 || bytesOut > 0 else { return }
        guard !notified.contains(name) else { return }
        notified.insert(name)

        let content = UNMutableNotificationContent()
        content.title = Localized.blockedAppNotificationTitle
        content.body = String(format: Localized.blockedAppNotificationBody, name)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "blocked-\(name)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
