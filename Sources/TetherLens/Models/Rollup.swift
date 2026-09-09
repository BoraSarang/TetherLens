import Foundation
import GRDB

/// 일·프로필 단위 사전집계 (v0.34). usage_log/session에서 재생성 가능하므로 원천 삭제 없이 유지한다.
struct DailyRollup: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_rollup"

    var id: String { "\(day)#\(profileId)" }
    let day: String  // yyyy-MM-dd (localtime)
    let profileId: UUID
    var uploadBytes: Int64
    var downloadBytes: Int64
    var sessionCount: Int
    var sessionSeconds: Int64

    enum CodingKeys: String, CodingKey {
        case day
        case profileId = "profile_id"
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
        case sessionCount = "session_count"
        case sessionSeconds = "session_seconds"
    }
}

/// 일·프로세스 단위 사전집계 (v0.34, 주범 추적용). app_traffic_log에서 재생성 가능.
struct AppDailyRollup: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "app_daily_rollup"

    var id: String { "\(day)#\(processName)" }
    let day: String  // yyyy-MM-dd (localtime)
    let processName: String
    var uploadBytes: Int64
    var downloadBytes: Int64

    enum CodingKeys: String, CodingKey {
        case day
        case processName = "process_name"
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
    }
}

/// 발행한 인사이트 이력 (v0.34). dedup_key로 중복 발행 방지.
struct InsightLog: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "insight_log"

    let id: UUID
    let kind: String  // pace | topOffender | anomaly | sessionEff
    let dedupKey: String
    let title: String
    let body: String
    var profileId: UUID?
    let createdAt: Date
    var shownCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case dedupKey = "dedup_key"
        case title
        case body
        case profileId = "profile_id"
        case createdAt = "created_at"
        case shownCount = "shown_count"
    }
}
