import Foundation

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: NotificationType
    let message: String

    enum NotificationType: String, Codable {
        case quotaWarning
        case quotaExceeded
        case connectionLost
        case connectionRestored
        case pingWarning
        case pingCritical
        case pingRecovery
    }
}
