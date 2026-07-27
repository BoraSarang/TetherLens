import Foundation
import GRDB

struct AppTrafficLog: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "app_traffic_log"

    let id: UUID
    let processName: String
    let uploadBytes: Int64
    let downloadBytes: Int64
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case processName = "process_name"
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
        case recordedAt = "recorded_at"
    }
}
