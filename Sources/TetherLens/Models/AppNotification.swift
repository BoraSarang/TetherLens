import Foundation

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: NotificationType
    let message: String
    /// 경고 해소 시각 (nil = 미해소). 기존 저장 JSON의 missing key는 nil로 디코딩된다.
    var resolvedAt: Date? = nil

    var isActive: Bool { resolvedAt == nil }

    /// warning-like 타입 판별 static 헬퍼
    static func isWarningLike(_ type: NotificationType) -> Bool {
        type.isWarningLike
    }

    enum NotificationType: String, Codable {
        case quotaWarning
        case quotaExceeded
        case connectionLost
        case connectionRestored
        case pingWarning
        case pingCritical
        case pingRecovery

        /// 복구 시 해소 대상인 경고성 알림.
        /// quotaWarning/quotaExceeded는 일 단위 누적이라 복구 개념이 없어 제외.
        var isWarningLike: Bool {
            switch self {
            case .pingWarning, .pingCritical, .connectionLost: return true
            default: return false
            }
        }
    }
}
