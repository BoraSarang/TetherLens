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
        #expect(!detector.isAndroidHotspotGateway("172.20.10.1"))
        #expect(!detector.isAndroidHotspotGateway("192.168.0.1"))
        #expect(!detector.isAndroidHotspotGateway(nil))
    }
}
