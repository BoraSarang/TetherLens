import Testing
import Foundation
@testable import TetherLens

@Suite struct SystemProcessesTests {

    @Test func 주요_시스템_프로세스_포함() {
        let set = SystemProcesses.set
        #expect(set.contains("kernel_task"))
        #expect(set.contains("launchd"))
        #expect(set.contains("WindowServer"))
        #expect(set.contains("configd"))
        #expect(set.contains("mDNSResponder"))
        #expect(set.contains("wifid"))
        #expect(set.contains("locationd"))
        #expect(set.contains("nsurlsessiond"))
    }

    @Test func 사용자_앱_제외() {
        let set = SystemProcesses.set
        #expect(!set.contains("Safari"))
        #expect(!set.contains("Chrome"))
        #expect(!set.contains("TetherLens"))
        #expect(!set.contains("Code"))
    }
}

@Suite struct LocalizedTests {

    @Test func string_ko_또는_en_반환() {
        let s = Localized.string("닫기", "Close")
        #expect(s == "닫기" || s == "Close")
    }

    @Test func 공통_키_존재() {
        #expect(!Localized.close.isEmpty)
        #expect(!Localized.settings.isEmpty)
        #expect(!Localized.hotspot.isEmpty)
        #expect(!Localized.quit.isEmpty)
        #expect(!Localized.more.isEmpty)
    }
}

@Suite struct HotspotDetectorTests {

    @Test func 안드로이드_SSID_판정() {
        let detector = HotspotDetector()
        #expect(detector.isAndroidSSID("Galaxy S23"))
        #expect(detector.isAndroidSSID("OkStart"))
        #expect(detector.isAndroidSSID("Redmi Note 10"))
        #expect(detector.isAndroidSSID("androidAP"))
        #expect(detector.isAndroidSSID("TP-LINK_1234"))
    }

    @Test func 일반_공유기_SSID_비판정() {
        let detector = HotspotDetector()
        #expect(!detector.isAndroidSSID("HomeWiFi"))
        #expect(!detector.isAndroidSSID("KT_GiGA_5G"))
        #expect(!detector.isAndroidSSID("SK_WiFi"))
        #expect(!detector.isAndroidSSID(nil))
    }

    @Test func 안드로이드_게이트웨이_대역_판정() {
        let detector = HotspotDetector()
        #expect(detector.isAndroidHotspotGateway("192.168.43.1"))
        #expect(detector.isAndroidHotspotGateway("192.168.49.1"))
        #expect(detector.isAndroidHotspotGateway("192.168.80.1"))
        #expect(detector.isAndroidHotspotGateway("192.168.42.1"))
        #expect(detector.isAndroidHotspotGateway("192.168.111.1"))
    }

    @Test func 비안드로이드_게이트웨이_비판정() {
        let detector = HotspotDetector()
        #expect(!detector.isAndroidHotspotGateway("10.229.78.251"))
        #expect(!detector.isAndroidHotspotGateway("192.168.0.1"))
        #expect(!detector.isAndroidHotspotGateway(nil))
        // 이례 대역(10.x)은 low 등급 — 단독으로는 확정 금지
        #expect(detector.androidGatewayTier("10.154.225.186") == .low)
        #expect(detector.androidGatewayTier("172.20.10.1") == .none)
    }

    @Test func S22_HotSpot_SSID_판정() {
        let detector = HotspotDetector()
        #expect(detector.isAndroidSSID("S22 HotSpot"))
        #expect(detector.androidSSIDScore("S22 HotSpot") >= 4)
    }

    @Test func 종합_득점_안드로이드_판별() {
        let detector = HotspotDetector()
        // S22 HotSpot + 10.154(통신사 CGNAT 유사): hotspot(2)+s22(2)+low게이트웨이(1) = 5점 → 안드로이드
        #expect(detector.androidHotspotScore(gatewayIP: "10.154.225.186", ssid: "S22 HotSpot", isExpensive: false))
        // 갤럭시 모델명 + hotspot → 안드로이드
        #expect(detector.androidHotspotScore(gatewayIP: "192.168.0.1", ssid: "Galaxy S23 HotSpot", isExpensive: false))
        // AndroidAP + 192.168.43 신뢰 대역 → 안드로이드
        #expect(detector.androidHotspotScore(gatewayIP: "192.168.43.1", ssid: "AndroidAP", isExpensive: false))
        // 비용(Cell) + 알려진 대역 → 안드로이드
        #expect(detector.androidHotspotScore(gatewayIP: "10.113.113.1", ssid: "Redmi_9", isExpensive: true))
    }

    @Test func 종합_득점_일반_공유기_비판별() {
        let detector = HotspotDetector()
        // 10.154 단독(SSID 일반) → 1점만, 임계 미달 → 안 분류
        #expect(!detector.androidHotspotScore(gatewayIP: "10.154.225.186", ssid: "HomeWiFi", isExpensive: false))
        // 일반 공유기 게이트웨이 + 일반 SSID
        #expect(!detector.androidHotspotScore(gatewayIP: "192.168.0.1", ssid: "KT_GiGA_5G", isExpensive: false))
        // iOS 핫스팟 게이트웨이(172.20.10) — 안드로이드 아님
        #expect(!detector.androidHotspotScore(gatewayIP: "172.20.10.1", ssid: "iPhone", isExpensive: true))
        // SSID만 hotspot("My_AP") + 일반 게이트웨이 → 2점 미달
        #expect(!detector.androidHotspotScore(gatewayIP: "192.168.10.1", ssid: "My_AP", isExpensive: false))
    }

    @Test func isExpensive_단독으로는_안드로이드_아님() {
        let detector = HotspotDetector()
        // isExpensive만 true(게이트웨이/SSID 신호 없음) → 1점 → 안드로이드 아님 (iOS 경로로 분기)
        #expect(!detector.androidHotspotScore(gatewayIP: "192.168.10.1", ssid: "HomeWiFi", isExpensive: true))
    }
}
