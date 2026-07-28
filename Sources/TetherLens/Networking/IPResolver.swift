import Foundation

struct GeoIPInfo: Codable {
    let ip: String
    let country: String?
    let countryCode: String?
}

@MainActor
class IPResolver {
    private(set) var externalIP: String?
    private(set) var geoInfo: GeoIPInfo?
    private var lastFetch: Date?

    func refresh(force: Bool = false) async {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) <= 300 { return }

        do {
            let url = URL(string: "https://api.ipify.org?format=json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let ipResult = try JSONDecoder().decode([String: String].self, from: data)
            externalIP = ipResult["ip"]

            if let ip = externalIP {
                let geoURL = URL(string: "https://ip-api.com/json/\(ip)?fields=status,country,countryCode")!
                let (geoData, _) = try await URLSession.shared.data(from: geoURL)
                geoInfo = try JSONDecoder().decode(GeoIPInfo.self, from: geoData)
            }

            lastFetch = Date()
        } catch {
        }
    }
}
