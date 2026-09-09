import Testing
import Foundation
@testable import TetherLens

/// v0.35 속도 테스트 — Mbps 산출 순수 함수 (실망 호출은 수동 검증)
@Suite struct SpeedTestTests {

    @Test func mbps_10MB_8초는_10Mbps() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 10_000_000, elapsed: 8) == 10.0)
    }

    @Test func mbps_1MB_1초는_8Mbps() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 1_000_000, elapsed: 1) == 8.0)
    }

    @Test func mbps_0바이트는_nil() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 0, elapsed: 5) == nil)
    }

    @Test func mbps_0초는_nil() {
        #expect(NetworkDiagnostics.megabitsPerSecond(bytes: 1000, elapsed: 0) == nil)
    }

    @Test func 속도측정_상수_정합() {
        #expect(NetworkDiagnostics.speedTestTimeout == 30)
        #expect(NetworkDiagnostics.speedTestDownBytes == 10_000_000)
        #expect(NetworkDiagnostics.speedTestUpBytes == 5_000_000)
    }
}
