import Foundation

/// 연결 상태 판정 정책 — ping(network probe) 결과와 OS 레벨(NWPathMonitor) 연결 상태를
/// 교차 검증해 "거짓 연결 끊김 알림"을 줄인다 (v0.31).
///
/// - OS가 만족(satisfied)하면 단발 ping 실패는 단순 드랍으로 간주 → 연속 실패가 일정 횟수
///   이상 쌓였을 때만 끊김으로 전환
/// - OS가 불만족(unsatisfied)이면 ping 성공 여부와 무관하게 즉시 끊김으로 처리
enum ReachabilityPolicy {
    /// 판정 횟수 (연속 ping 실패). 값이 늘면 그만큼 못내린다.
    static let defaultStrikeLimit = 3

    /// 상태 전이를 결정하는 순수 함수. 사이드 이펙트 없음 → 유닛 테스트 가능.
    /// - Parameters:
    ///   - pingAlive: 이번 probe에서 게이트웨이/외부 호스트 중 하나라도 응답
    ///   - osAvailable: NWPathMonitor가 `.satisfied` (OS 레벨 연결 성립)
    ///   - strikes: 이전까지 연속 실패 횟수
    /// - Returns: 실제로 "연결됨"으로 볼지와 다음 strikes
    static func evaluate(pingAlive: Bool, osAvailable: Bool, strikes: Int, strikeLimit: Int = defaultStrikeLimit) -> (reachable: Bool, newStrikes: Int) {
        if osAvailable {
            if pingAlive {
                return (true, 0)
            } else {
                let next = strikes + 1
                return (next < strikeLimit, next)
            }
        } else {
            // OS 레벨에서 경로가 없음 → ping 결과와 무관하게 즉시 끊김
            return (false, strikes + 1)
        }
    }
}