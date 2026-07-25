import Foundation
import GRDB

struct Profile: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profile"

    let id: UUID
    let ssid: String
    var name: String
    var quotaGB: Double?
    var createdAt: Date
    var lastConnected: Date

    enum CodingKeys: String, CodingKey {
        case id, ssid, name
        case quotaGB = "quota_gb"
        case createdAt = "created_at"
        case lastConnected = "last_connected"
    }
}
