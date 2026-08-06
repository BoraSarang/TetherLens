import Foundation
import GRDB

struct Session: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "session"

    let id: UUID
    let profileId: UUID
    let startTime: Date
    var endTime: Date?
    var latitude: Double?
    var longitude: Double?
    var locationSource: String?  // "gps" | "ip" | nil

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case latitude
        case longitude
        case locationSource = "location_source"
    }
}
