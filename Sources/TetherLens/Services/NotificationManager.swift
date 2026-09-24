import Foundation

final class NotificationManager: ObservableObject, @unchecked Sendable {
    static let shared = NotificationManager()

    @Published private(set) var notifications: [AppNotification] = []

    private let maxCount = 50
    private let defaults: UserDefaults
    private let key = "savedNotifications"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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

    /// 해당 type의 미해소(resolvedAt nil) 항목 전부를 해소 시각으로 마킹 + 저장.
    func resolve(types: Set<AppNotification.NotificationType>) {
        mutateSync { notes in
            let now = Date()
            for i in notes.indices
            where notes[i].resolvedAt == nil && types.contains(notes[i].type) {
                notes[i].resolvedAt = now
            }
        }
    }

    /// 해당 타입의 활성 알림 해소
    func resolve(type: AppNotification.NotificationType) {
        resolve(types: [type])
    }

    /// 특정 알림 해소
    func resolve(id: UUID) {
        mutateSync { notes in
            guard let i = notes.firstIndex(where: { $0.id == id && $0.resolvedAt == nil }) else { return }
            notes[i].resolvedAt = Date()
        }
    }

    /// 복구 시 호출 — 경고성 type 전체(pingWarning/pingCritical/connectionLost) 해소.
    func resolveWarnings() {
        resolve(types: [.pingWarning, .pingCritical, .connectionLost])
    }

    /// 미해소 경고 알림 목록
    var activeWarnings: [AppNotification] {
        notifications.filter { $0.isActive && AppNotification.isWarningLike($0.type) }
    }

    func clearAll() {
        notifications = []
        save()
    }

    /// 해소 API는 동기 — 호출 직후 관찰 가능해야 한다. main 아니면 main에서 동기 실행해 @Published 안전성 보장.
    private func mutateSync(_ body: (inout [AppNotification]) -> Void) {
        func apply() {
            var notes = notifications
            body(&notes)
            notifications = notes
            save()
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.sync(execute: apply)
        }
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
