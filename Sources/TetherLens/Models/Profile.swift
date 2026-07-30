import Foundation
import GRDB

struct Profile: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profile"

    let id: UUID
    let ssid: String
    var name: String
    var quotaGB: Double?
    var connectionType: String?
    var createdAt: Date
    var lastConnected: Date

    enum CodingKeys: String, CodingKey {
        case id, ssid, name
        case quotaGB = "quota_gb"
        case connectionType = "connection_type"
        case createdAt = "created_at"
        case lastConnected = "last_connected"
    }

    var resolvedConnectionType: String {
        connectionType ?? Self.classifiedConnectionType(ssid: ssid)
    }

    var isHotspot: Bool {
        let t = resolvedConnectionType
        return t == "ios_hotspot" || t == "android_hotspot"
    }

    var typeLabel: String? {
        switch resolvedConnectionType {
        case "ios_hotspot", "android_hotspot": return Localized.hotspot
        case "ethernet": return Localized.ethernet
        default: return nil
        }
    }

    static func classifiedConnectionType(ssid: String) -> String {
        let upper = ssid.uppercased()
        if containsIPhonePattern(upper) { return "ios_hotspot" }
        if containsAndroidPattern(upper) { return "android_hotspot" }
        return "wifi"
    }

    private static func containsIPhonePattern(_ s: String) -> Bool {
        s.contains("IPHONE") || s.contains("IPAD") || s.contains("IPOD")
    }

    private static func containsAndroidPattern(_ s: String) -> Bool {
        s.contains("GALAXY") || s.contains("SM-") || s.contains("ANDROIDAP")
    }
}
