import Foundation

final class NotificationManager: ObservableObject, @unchecked Sendable {
    static let shared = NotificationManager()

    @Published private(set) var notifications: [AppNotification] = []

    private let maxCount = 50
    private let defaults = UserDefaults.standard
    private let key = "savedNotifications"

    private init() {
        load()
    }

    func add(type: AppNotification.NotificationType, message: String) {
        let note = AppNotification(id: UUID(), timestamp: Date(), type: type, message: message)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.notifications.insert(note, at: 0)
            if self.notifications.count > self.maxCount {
                self.notifications = Array(self.notifications.prefix(self.maxCount))
            }
            self.save()
        }
    }

    func clearAll() {
        notifications = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notifications) {
            defaults.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data)
        else { return }
        notifications = decoded
    }
}
