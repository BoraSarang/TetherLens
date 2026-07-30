import Foundation

struct GeoIPInfo: Codable {
    let ip: String
    let country: String
    let latitude: Double?
    let longitude: Double?

    var countryCode: String { country }
    var location: (latitude: Double, longitude: Double)? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return (lat, lng)
    }
}

@MainActor
class IPResolver {
    private(set) var externalIP: String?
    private(set) var geoInfo: GeoIPInfo?
    var resolvedLocation: (latitude: Double, longitude: Double)? {
        geoInfo?.location
    }
    private var lastFetch: Date?

    func refresh(force: Bool = false) async {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) <= 300 {
            DebugLogger.shared.info("Network", "IP 갱신 스킵 (쿨다운 중, force=\(force))")
            return
        }
        DebugLogger.shared.action("Network", "외부 IP 갱신 시작 (force=\(force))")

        do {
            let url = URL(string: "https://api.ipify.org?format=json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let ipResult = try JSONDecoder().decode([String: String].self, from: data)
            externalIP = ipResult["ip"]
            DebugLogger.shared.apiCall("Network", "GET", "https://api.ipify.org?format=json")
            DebugLogger.shared.apiResponse("Network", 200, "api.ipify.org", body: ["ip": externalIP ?? ""])

            if let ip = externalIP {
                let geoURL = URL(string: "https://ipapi.co/\(ip)/json/")!
                DebugLogger.shared.apiCall("Network", "GET", "https://ipapi.co/\(ip)/json/")
                let (geoData, _) = try await URLSession.shared.data(from: geoURL)
                geoInfo = try JSONDecoder().decode(GeoIPInfo.self, from: geoData)
                if let loc = geoInfo?.location {
                    DebugLogger.shared.apiResponse("Network", 200, "ipapi.co", body: "lat=\(loc.latitude) lng=\(loc.longitude) country=\(geoInfo?.country ?? "")")
                } else {
                    DebugLogger.shared.apiResponse("Network", 200, "ipapi.co", body: "country=\(geoInfo?.country ?? "") (no location)")
                }
            }

            lastFetch = Date()
        } catch {
            DebugLogger.shared.error("Network", "IP 조회 실패: \(error.localizedDescription)")
        }
    }
}
