import Foundation
import GRDB

struct UsageLog: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "usage_log"

    let id: UUID
    let profileId: UUID
    let uploadDelta: Int64
    let downloadDelta: Int64
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case uploadDelta = "upload_delta"
        case downloadDelta = "download_delta"
        case recordedAt = "recorded_at"
    }
}
