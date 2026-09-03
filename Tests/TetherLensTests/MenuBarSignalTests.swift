import Testing
import SwiftUI
@testable import TetherLens

/// 메뉴바/플로팅 col3의 RSSI·지연시간 형식·색상 검증 (v0.31) — 할당량 미설정 시 표시
@Suite struct MenuBarSignalTests {

    // MARK: 형식

    @Test func RSSI_형식() {
        #expect(MenuBarManager.rssiString(-57) == "-57 dBm")
        #expect(MenuBarManager.rssiString(-50) == "-50 dBm")
        #expect(MenuBarManager.rssiString(nil) == "--")
    }

    @Test func 지연_형식() {
        #expect(MenuBarManager.latencyString(0.012) == "12 ms")
        #expect(MenuBarManager.latencyString(0.15) == "150 ms")
        #expect(MenuBarManager.latencyString(nil) == "--")
    }

    // MARK: RSSI 신호 색상

    @Test func RSSI_강함_초록() {
        #expect(MenuBarManager.rssiColor(-40) == TLPalette.success)
        #expect(MenuBarManager.rssiColor(-50) == TLPalette.success)
    }

    @Test func RSSI_보통_주황() {
        #expect(MenuBarManager.rssiColor(-60) == TLPalette.upload)
        #expect(MenuBarManager.rssiColor(-67) == TLPalette.upload)
    }

    @Test func RSSI_약함_빨강() {
        #expect(MenuBarManager.rssiColor(-68) == TLPalette.danger)
        #expect(MenuBarManager.rssiColor(-90) == TLPalette.danger)
    }

    @Test func RSSI_없음_중립() {
        #expect(MenuBarManager.rssiColor(nil) == TLPalette.textSecondary)
    }

    // MARK: 지연 색상

    @Test func 지연_양호_초록() {
        #expect(MenuBarManager.latencyColor(0.01) == TLPalette.success)
        #expect(MenuBarManager.latencyColor(0.049) == TLPalette.success)
    }

    @Test func 지연_보통_주황() {
        #expect(MenuBarManager.latencyColor(0.05) == TLPalette.upload)
        #expect(MenuBarManager.latencyColor(0.149) == TLPalette.upload)
    }

    @Test func 지연_불량_빨강() {
        #expect(MenuBarManager.latencyColor(0.15) == TLPalette.danger)
        #expect(MenuBarManager.latencyColor(0.5) == TLPalette.danger)
    }

    @Test func 지연_없음_중립() {
        #expect(MenuBarManager.latencyColor(nil) == TLPalette.textSecondary)
    }
}