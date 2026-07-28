import Foundation

struct GeoIPInfo: Codable {
    let ip: String
    let country: String

    var countryCode: String { country }
}

@MainActor
class IPResolver {
    private(set) var externalIP: String?
    private(set) var geoInfo: GeoIPInfo?
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
                let geoURL = URL(string: "https://ipinfo.io/\(ip)/json")!
                DebugLogger.shared.apiCall("Network", "GET", "https://ipinfo.io/\(ip)/json")
                let (geoData, _) = try await URLSession.shared.data(from: geoURL)
                geoInfo = try JSONDecoder().decode(GeoIPInfo.self, from: geoData)
                DebugLogger.shared.apiResponse("Network", 200, "ipinfo.io", body: geoInfo.map { "country=\($0.country) code=\($0.countryCode)" })
            }

            lastFetch = Date()
        } catch {
            DebugLogger.shared.error("Network", "IP 조회 실패: \(error.localizedDescription)")
        }
    }
}
