import Testing
import Foundation
@testable import TetherLens

/// v0.35 연결 유지 — 자동 시도 조건 + 장치명 파싱 (실 networksetup 호출은 수동 검증)
@Suite struct ConnectionGuardianTests {

    @Test func 자동꺼짐이면_시도안함() {
        #expect(!ConnectionGuardian.shouldAutoReconnect(autoEnabled: false, lastAttempt: nil))
    }

    @Test func 첫끊김은_시도함() {
        #expect(ConnectionGuardian.shouldAutoReconnect(autoEnabled: true, lastAttempt: nil))
    }

    @Test func 쿨다운내_재시도안함() {
        let now = Date()
        let last = now.addingTimeInterval(-60)
        #expect(!ConnectionGuardian.shouldAutoReconnect(autoEnabled: true, lastAttempt: last, now: now))
    }

    @Test func 쿨다운경과_재시도함() {
        let now = Date()
        let last = now.addingTimeInterval(-301)
        #expect(ConnectionGuardian.shouldAutoReconnect(autoEnabled: true, lastAttempt: last, now: now))
    }

    @Test func 장치명_WiFi에서_en0추출() {
        let out = """
        Hardware Port: Wi-Fi
        Device: en0
        Ethernet Address: aa:bb:cc:dd:ee:ff

        Hardware Port: Bluetooth PAN
        Device: en4
        """
        #expect(ConnectionGuardian.parseWifiInterface(out) == "en0")
    }

    @Test func 장치명_WiFi없으면_nil() {
        let out = """
        Hardware Port: Bluetooth PAN
        Device: en4
        """
        #expect(ConnectionGuardian.parseWifiInterface(out) == nil)
    }
}
