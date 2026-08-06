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
    var onIPChange: ((String?, String, GeoIPInfo?) -> Void)?
    private var lastFetch: Date?
    private var isRefreshing = false

    func refresh(force: Bool = false) async {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) <= 300 {
            DebugLogger.shared.info("Network", "IP 갱신 스킵 (쿨다운 중, force=\(force))")
            return
        }
        guard !isRefreshing else {
            DebugLogger.shared.info("Network", "IP 갱신 스킵 (이미 갱신 중)")
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        DebugLogger.shared.action("Network", "외부 IP 갱신 시작 (force=\(force))")
        let oldIP = externalIP

        do {
            let url = URL(string: "https://api.ipify.org?format=json")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)
            let ipResult = try JSONDecoder().decode([String: String].self, from: data)
            let newIP = ipResult["ip"]
            DebugLogger.shared.apiCall("Network", "GET", "https://api.ipify.org?format=json")
            DebugLogger.shared.apiResponse("Network", 200, "api.ipify.org", body: ["ip": newIP ?? ""])

            if let ip = newIP {
                let geoURL = URL(string: "https://ipapi.co/\(ip)/json/")!
                DebugLogger.shared.apiCall("Network", "GET", "https://ipapi.co/\(ip)/json/")
                var geoRequest = URLRequest(url: geoURL)
                geoRequest.timeoutInterval = 10
                let (geoData, _) = try await URLSession.shared.data(for: geoRequest)
                let newGeo = try JSONDecoder().decode(GeoIPInfo.self, from: geoData)
                geoInfo = newGeo
                if let loc = newGeo.location {
                    DebugLogger.shared.apiResponse("Network", 200, "ipapi.co", body: "lat=\(loc.latitude) lng=\(loc.longitude) country=\(newGeo.country)")
                } else {
                    DebugLogger.shared.apiResponse("Network", 200, "ipapi.co", body: "country=\(newGeo.country) (no location)")
                }
                externalIP = ip
                if ip != oldIP {
                    onIPChange?(oldIP, ip, newGeo)
                }
            }

            lastFetch = Date()
        } catch {
            DebugLogger.shared.error("Network", "IP 조회 실패: \(error.localizedDescription)")
        }
    }
}
