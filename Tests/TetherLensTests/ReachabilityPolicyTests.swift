import Testing
import Foundation
@testable import TetherLens

/// ReachabilityPolicy 상태 전이 검증 (v0.31) — 거짓 끊김 알림 방지 정책
@Suite struct ReachabilityPolicyTests {

    @Test func OS정상_ping성공_연결유지_및_스트라이크_리셋() {
        let r = ReachabilityPolicy.evaluate(pingAlive: true, osAvailable: true, strikes: 0)
        #expect(r.reachable == true)
        #expect(r.newStrikes == 0)
    }

    @Test func 단발드랍_OS정상_끊김아님_스트라이크만_증가() {
        let r = ReachabilityPolicy.evaluate(pingAlive: false, osAvailable: true, strikes: 0)
        #expect(r.reachable == true, "단발 드랍은 연결 유지")
        #expect(r.newStrikes == 1)
    }

    @Test func 연속드랍_임계미만_연결유지() {
        let r = ReachabilityPolicy.evaluate(pingAlive: false, osAvailable: true, strikes: ReachabilityPolicy.defaultStrikeLimit - 2)
        #expect(r.reachable == true, "2연속 실패까지는 연결 유지")
        #expect(r.newStrikes == ReachabilityPolicy.defaultStrikeLimit - 1)
    }

    @Test func 연속드랍_임계도달_끊김_전환() {
        let r = ReachabilityPolicy.evaluate(pingAlive: false, osAvailable: true, strikes: 2)
        #expect(r.reachable == false, "3연속 실패면 끊김")
        #expect(r.newStrikes == 3)
    }

    @Test func OS불만족_즉시_끊김() {
        let r = ReachabilityPolicy.evaluate(pingAlive: true, osAvailable: false, strikes: 0)
        #expect(r.reachable == false, "OS unsatisfied는 ping과 무관하게 끊김")
    }

    @Test func 성공시_스트라이크_초기화_복구() {
        let r1 = ReachabilityPolicy.evaluate(pingAlive: false, osAvailable: true, strikes: 2)
        #expect(r1.reachable == false)
        let r2 = ReachabilityPolicy.evaluate(pingAlive: true, osAvailable: true, strikes: r1.newStrikes)
        #expect(r2.reachable == true)
        #expect(r2.newStrikes == 0, "성공하면 스트라이크 리셋")
    }

    @Test func 임계값_설정_변경() {
        let r = ReachabilityPolicy.evaluate(pingAlive: false, osAvailable: true, strikes: 1, strikeLimit: 2)
        #expect(r.reachable == false, "limit 2면 2연속 실패 시 끊김")
    }
}