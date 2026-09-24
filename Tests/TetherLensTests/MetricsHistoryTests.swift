import Testing
import Foundation
@testable import TetherLens

@Suite struct MetricsHistoryTests {

    @Test @MainActor func 링버퍼_용량_초과시_오래된값_제거() {
        let history = MetricsHistory.shared
        history.reset()
        for i in 0..<(MetricsHistory.capacity + 10) {
            history.push(cpu: Double(i), gpu: nil, memPercent: nil)
        }
        #expect(history.cpuHistory.count == MetricsHistory.capacity)
        #expect(history.cpuHistory.first == 10)
        #expect(history.cpuHistory.last == Double(MetricsHistory.capacity + 9))
        history.reset()
    }

    @Test @MainActor func nil항목은_이번틱_건너뜀() {
        let history = MetricsHistory.shared
        history.reset()
        history.push(cpu: 5, gpu: nil, memPercent: nil)
        #expect(history.cpuHistory.count == 1)
        #expect(history.gpuHistory.isEmpty)
        #expect(history.memHistory.isEmpty)
        history.reset()
    }

    @Test @MainActor func 값은_0에서_100으로_클램프() {
        #expect(MetricsHistory.clamp(-5) == 0)
        #expect(MetricsHistory.clamp(150) == 100)
        #expect(MetricsHistory.clamp(42.5) == 42.5)
    }

    @Test @MainActor func 시스템스냅샷_push_메모리사용률() {
        let history = MetricsHistory.shared
        history.reset()
        let load = SystemLoad(
            cpuTotalPercent: 25,
            memUsedBytes: 4_000_000_000,
            memTotalBytes: 8_000_000_000,
            gpuPercent: 10
        )
        history.push(system: load)
        #expect(history.cpuHistory == [25])
        #expect(history.gpuHistory == [10])
        #expect(history.memHistory == [50])
        history.reset()
    }

    @Test @MainActor func 메모리사용량_실패시_mem히스토리_미포함() {
        let history = MetricsHistory.shared
        history.reset()
        let load = SystemLoad(cpuTotalPercent: 10, memUsedBytes: -1, memTotalBytes: 100, gpuPercent: nil)
        history.push(system: load)
        #expect(history.memHistory.isEmpty)
        #expect(history.gpuHistory.isEmpty)
        #expect(history.cpuHistory == [10])
        history.reset()
    }
}

@Suite struct SystemLoadFormatTests {

    @Test func 메모리_사용_총량_표시() {
        let used = Int64(4.9 * 1_073_741_824)
        let total = Int64(7 * 1_073_741_824)
        #expect(SystemResourceMonitor.formatMemUsedTotal(used: used, total: total) == "4.9 / 7 GB")
        #expect(SystemResourceMonitor.formatMemUsedTotal(used: total, total: total) == "7 / 7 GB")
    }

    @Test func 메모리_실패시_대시() {
        #expect(SystemResourceMonitor.formatMemUsedTotal(used: -1, total: 8 * 1_073_741_824) == "–")
        #expect(SystemResourceMonitor.formatMemUsedTotal(used: 100, total: 0) == "–")
    }

    @Test func 코어_tick_델타_사용률() {
        // user, system, idle, nice
        let prev: [[UInt64]] = [[100, 50, 850, 0]]
        let curr: [[UInt64]] = [[150, 70, 880, 0]]
        // busy 70 / total 100 → 70%
        let result = SystemResourceMonitor.perCorePercent(prev: prev, curr: curr)
        #expect(result.count == 1)
        #expect(abs(result[0] - 70) < 0.001)
    }

    @Test func 코어_전부_유휴면_0() {
        let prev: [[UInt64]] = [[0, 0, 100, 0]]
        let curr: [[UInt64]] = [[0, 0, 200, 0]]
        #expect(SystemResourceMonitor.perCorePercent(prev: prev, curr: curr) == [0])
    }

    @Test func 코어_불변분모면_0() {
        let prev: [[UInt64]] = [[10, 10, 10, 10]]
        #expect(SystemResourceMonitor.perCorePercent(prev: prev, curr: prev) == [0])
    }

    @Test func 코어_길이_불일치_스킵() {
        #expect(SystemResourceMonitor.perCorePercent(prev: [[1, 1, 1, 1]], curr: []) == [])
    }
}

@Suite struct TLShareTests {

    @Test func 합계대비_비율() {
        #expect(TLShare.ratio(50, of: 100) == 0.5)
        #expect(TLShare.ratio(0, of: 100) == 0)
        #expect(TLShare.ratio(100, of: 100) == 1)
    }

    @Test func 분모_0이하면_0() {
        #expect(TLShare.ratio(10, of: 0) == 0)
        #expect(TLShare.ratio(10, of: -1) == 0)
    }

    @Test func 결과는_0과1_사이로_클램프() {
        #expect(TLShare.ratio(200, of: 100) == 1)
        #expect(TLShare.ratio(-5, of: 100) == 0)
        #expect(TLShare.ratio(Double.nan, of: 100) == 0)
        #expect(TLShare.ratio(10, of: Double.nan) == 0)
    }
}

@Suite struct GPUParseTests {

    @Test func 알려진키_DeviceUtilization() {
        let stats: [String: Any] = ["Device Utilization %": 42]
        #expect(SystemResourceMonitor.parseGPUUtilization(from: stats) == 42)
    }

    @Test func GPUActivity_퍼센트_키() {
        let stats: [String: Any] = ["GPU Activity(%)": 87.5]
        #expect(SystemResourceMonitor.parseGPUUtilization(from: stats) == 87.5)
    }

    @Test func NSNumber_박스() {
        let stats: [String: Any] = ["Device Utilization %": NSNumber(value: 33)]
        #expect(SystemResourceMonitor.parseGPUUtilization(from: stats) == 33)
    }

    @Test func 알수없는_딕셔너리_nil() {
        #expect(SystemResourceMonitor.parseGPUUtilization(from: [:]) == nil)
        #expect(SystemResourceMonitor.parseGPUUtilization(from: ["foo": 1]) == nil)
    }

    @Test func 음수값_nil처리() {
        // 음수는 유효하지 않으나 value >= 0 조건에서 걸러짐 → nil
        let stats: [String: Any] = ["Device Utilization %": -1]
        #expect(SystemResourceMonitor.parseGPUUtilization(from: stats) == nil)
    }

    @Test func 초과값_100으로_클램프() {
        let stats: [String: Any] = ["Device Utilization %": 150]
        #expect(SystemResourceMonitor.parseGPUUtilization(from: stats) == 100)
    }
}
