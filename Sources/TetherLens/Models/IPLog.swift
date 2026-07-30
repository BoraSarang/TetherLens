import Foundation
import GRDB

struct IPLog: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "ip_log"

    let id: UUID
    let profileId: UUID
    let ipAddress: String
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let firstSeenAt: Date
    var lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case ipAddress = "ip_address"
        case country
        case latitude
        case longitude
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
    }
}
