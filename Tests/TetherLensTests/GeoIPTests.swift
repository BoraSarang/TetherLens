import Testing
import Foundation
@testable import TetherLens

/// v0.39 T-250 #7 — ipapi.co 의 `country`(국가명)를 국가 코드로 착각해
/// 잘못된 국기 글리프를 렌더링하던 결함의 회귀 테스트
@Suite struct GeoIPTests {

    private func decode(_ json: String) throws -> GeoIPInfo {
        try JSONDecoder().decode(GeoIPInfo.self, from: Data(json.utf8))
    }

    // MARK: - country_code 디코딩

    @Test func country_code를_alpha2로_읽는다() throws {
        let geo = try decode("""
        {"ip":"1.2.3.4","country":"South Korea","country_code":"kr",\
        "latitude":37.5,"longitude":127.0}
        """)
        #expect(geo.countryCode == "KR")   // 소문자 응답도 대문자로 정규화
        #expect(geo.country == "South Korea")
    }

    /// 응답에 `country_code` 가 없으면 nil — 예전처럼 국가명으로 대체하지 않는다
    @Test func country_code가_없으면_nil이다() throws {
        let geo = try decode("""
        {"ip":"1.2.3.4","country":"South Korea","latitude":37.5,"longitude":127.0}
        """)
        #expect(geo.countryCode == nil)
    }

    /// 국가명이 alpha-2 형식이 아니면 코드로 승격시키지 않는다 (핵심 회귀)
    @Test func 국가명은_코드로_승격하지_않는다() throws {
        let geo = try decode("""
        {"ip":"1.2.3.4","country":"United States","country_code":"US",\
        "latitude":38.0,"longitude":-77.0}
        """)
        // country_code 가 정상 있으면 코드는 얻지만, 국가명으로 대체하진 않는다
        #expect(geo.countryCode == "US")
        #expect(geo.countryCode != geo.country)

        let noCode = try decode("""
        {"ip":"1.2.3.4","country":"United States","latitude":38.0,"longitude":-77.0}
        """)
        #expect(noCode.countryCode == nil)
    }

    // MARK: - alpha-2 검증

    @Test func alpha2는_대문자두글자만_통과한다() {
        #expect(GeoIPInfo.normalizedAlpha2("KR") == "KR")
        #expect(GeoIPInfo.normalizedAlpha2("kr") == "KR")
        #expect(GeoIPInfo.normalizedAlpha2("us") == "US")
        #expect(GeoIPInfo.normalizedAlpha2("K") == nil)
        #expect(GeoIPInfo.normalizedAlpha2("KOR") == nil)
        #expect(GeoIPInfo.normalizedAlpha2("K1") == nil)
        #expect(GeoIPInfo.normalizedAlpha2("K🇰") == nil)
        #expect(GeoIPInfo.normalizedAlpha2("") == nil)
        #expect(GeoIPInfo.normalizedAlpha2(nil) == nil)
    }

    /// 한국어 국가명처럼 2바이트 문자가 섞인 문자열도 통과해서는 안 된다
    @Test func 비ASCII문자열은_거부된다() {
        #expect(GeoIPInfo.normalizedAlpha2("한국") == nil)
        #expect(GeoIPInfo.normalizedAlpha2("South Korea") == nil)
    }

    // MARK: - 국기 이모지

    @Test func KR은_한국국기로_렌더링된다() {
        let flag = GeoIPInfo.flagEmoji(forCountryCode: "KR")
        #expect(flag?.unicodeScalars.count == 2)
        // U+1F1F0 (K) + U+1F1F7 (R) — 리터럴 이모지 대신 스칼라로 비교한다
        #expect(flag?.unicodeScalars.map(\.value) == [0x1F1F0, 0x1F1F7])
    }

    /// 국가명을 넘기면 예전처럼 11개 글리프로 조각난 국기가 나오지 않고 nil 이 된다
    @Test func 국가명으로_국기를_만들지_않는다() {
        #expect(GeoIPInfo.flagEmoji(forCountryCode: "South Korea") == nil)
        #expect(GeoIPInfo.flagEmoji(forCountryCode: nil) == nil)
    }

    /// 예전 구현은 `UnicodeScalar(base + value)!` 강제 해제라 범위를 벗어나면 크래시했다
    @Test func 범위를_벗어나는_입력은_크래시하지_않는다() {
        #expect(GeoIPInfo.flagEmoji(forCountryCode: "\u{10FFFF}\u{10FFFF}") == nil)
        #expect(GeoIPInfo.flagEmoji(forCountryCode: "🇰🇷") == nil)
    }

    // MARK: - 위치

    @Test func location은_좌표가_있을때만_반환한다() throws {
        let withLoc = try decode("""
        {"ip":"1.2.3.4","country":"South Korea","country_code":"KR",\
        "latitude":37.5,"longitude":127.0}
        """)
        #expect(withLoc.location?.latitude == 37.5)

        let noLoc = try decode("""
        {"ip":"1.2.3.4","country":"South Korea","country_code":"KR"}
        """)
        #expect(noLoc.location == nil)
    }
}
