import Foundation
import Combine

/// 시스템 CPU/GPU/MEM 사용률 링 버퍼 (v0.37) — iStat 스타일 스파크라인용.
/// - `TrafficMonitor.refresh()` 메인 갱신 시점에만 push한다 (추가 타이머 없음).
/// - capacity 60 × 기본 주기 10초 ≈ 10분 윈도우.
@MainActor
final class MetricsHistory: ObservableObject {
    static let shared = MetricsHistory()
    static let capacity = 60

    /// 3개 지표를 한 번에 발행 — 카드 무효화 최대 3회 → 1회 (v0.38.1)
    struct Snapshot: Equatable {
        var cpu: [Double] = []
        var gpu: [Double] = []
        var mem: [Double] = []
    }

    @Published private(set) var snapshot = Snapshot()

    var cpuHistory: [Double] { snapshot.cpu }
    var gpuHistory: [Double] { snapshot.gpu }
    var memHistory: [Double] { snapshot.mem }

    private init() {}

    /// 시스템 스냅샷 push — nil 항목은 이번 틱에서 건너뛴다 (GPU 미지원 등).
    func push(system: SystemLoad) {
        let memPercent: Double?
        if system.memUsedBytes >= 0, system.memTotalBytes > 0 {
            memPercent = Double(system.memUsedBytes) / Double(system.memTotalBytes) * 100
        } else {
            memPercent = nil
        }
        push(cpu: system.cpuTotalPercent, gpu: system.gpuPercent, memPercent: memPercent)
    }

    func push(cpu: Double?, gpu: Double?, memPercent: Double?) {
        var next = snapshot
        if let cpu { Self.ring(&next.cpu, Self.clamp(cpu)) }
        if let gpu { Self.ring(&next.gpu, Self.clamp(gpu)) }
        if let memPercent { Self.ring(&next.mem, Self.clamp(memPercent)) }
        if next != snapshot {
            snapshot = next
        }
    }

    func reset() {
        snapshot = Snapshot()
    }

    static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    static func ring(_ array: inout [Double], _ value: Double) {
        array.append(value)
        if array.count > capacity {
            array.removeFirst(array.count - capacity)
        }
    }
}
