import Foundation

struct GeoIPInfo: Codable {
    let ip: String
    /// ipapi.co 가 주는 **국가명** ("South Korea") — 국기 글리프로 바꿀 수 없다
    let country: String
    /// ipapi.co 가 함께 주는 ISO 3166-1 alpha-2 코드 ("KR")
    let countryCodeRaw: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case ip, country, latitude, longitude
        case countryCodeRaw = "country_code"
    }

    /// ISO 3166-1 alpha-2 대문자 코드. 값이 없으면 nil.
    ///
    /// ⚠️ 예전에는 `country`(국가명)를 그대로 코드처럼 썼다가 국가명 전체를
    ///    지역 표시기 문자로 변환해 잘못된 국기가 렌더링되었다(T-250 #7).
    ///    코드가 아닌 문자열은 **nil 로 두고 국기를 생략**한다.
    var countryCode: String? { Self.normalizedAlpha2(countryCodeRaw) }

    var location: (latitude: Double, longitude: Double)? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return (lat, lng)
    }

    /// alpha-2 코드 검증 — 대문자 A-Z 2자만 통과
    static func normalizedAlpha2(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let up = raw.uppercased()
        guard up.count == 2,
              up.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else { return nil }
        return up
    }

    /// alpha-2 코드 → 국기 이모지. 코드가 아니면 nil.
    ///
    /// 지역 표시기 기호는 U+1F1E6(A) + (문자 - 'A') 이므로, 두 글자가 유효한
    /// 대문자 ASCII 여야 한다. 예전 구현은 `UnicodeScalar(...)!` 강제 해제라
    /// 입력 범위를 벗어나면 크래시했다 — 여기서는 nil 을 돌려준다.
    static func flagEmoji(forCountryCode raw: String?) -> String? {
        guard let code = normalizedAlpha2(raw) else { return nil }
        let base: UInt32 = 127_397  // U+1F1E6
        var out = String.UnicodeScalarView()
        for scalar in code.unicodeScalars {
            guard let s = UnicodeScalar(base + scalar.value) else { return nil }
            out.append(s)
        }
        return String(out)
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
            guard let url = URL(string: "https://api.ipify.org?format=json") else {
                DebugLogger.shared.error("Network", "IP 조회 URL 생성 실패")
                return
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)
            let ipResult = try JSONDecoder().decode([String: String].self, from: data)
            let newIP = ipResult["ip"]
            DebugLogger.shared.apiCall("Network", "GET", "https://api.ipify.org?format=json")
            DebugLogger.shared.apiResponse("Network", 200, "api.ipify.org", body: ["ip": newIP ?? ""])

            if let ip = newIP {
                // 공인 IP가 기존과 동일하면 지역 조회를 생략한다 (에너지/API 절감 — v0.28.2).
                guard ip != externalIP else {
                    DebugLogger.shared.info("Network", "IP 동일(\(ip)) — 지역 조회 생략")
                    lastFetch = Date()
                    return
                }
                guard let geoURL = URL(string: "https://ipapi.co/\(ip)/json/") else {
                    DebugLogger.shared.error("Network", "지역 조회 URL 생성 실패 (ip=\(ip))")
                    externalIP = ip
                    lastFetch = Date()
                    return
                }
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
