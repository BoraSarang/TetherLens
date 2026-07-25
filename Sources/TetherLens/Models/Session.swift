import Foundation
import GRDB

struct Session: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "session"

    let id: UUID
    let profileId: UUID
    let startTime: Date
    var endTime: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
