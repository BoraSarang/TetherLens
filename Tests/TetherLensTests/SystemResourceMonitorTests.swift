import Testing
import Foundation
@testable import TetherLens

@Suite struct SystemResourceMonitorTests {

    @Test func pid_접미사_제거() {
        #expect(SystemResourceMonitor.stripPidSuffix("Safari.1234") == "Safari")
        #expect(SystemResourceMonitor.stripPidSuffix("Google Chrome Helper.5678") == "Google Chrome Helper")
        #expect(SystemResourceMonitor.stripPidSuffix("a.b.567") == "a.b")
    }

    @Test func pid_접미사_없으면_유지() {
        #expect(SystemResourceMonitor.stripPidSuffix("Safari") == "Safari")
        #expect(SystemResourceMonitor.stripPidSuffix("foo.bar") == "foo.bar")
        #expect(SystemResourceMonitor.stripPidSuffix("") == "")
        #expect(SystemResourceMonitor.stripPidSuffix(".123") == ".123")
    }

    @Test func 경로_베이스네임() {
        #expect(SystemResourceMonitor.baseName(fromPath: "/Applications/Safari.app/Contents/MacOS/Safari") == "Safari")
        #expect(SystemResourceMonitor.baseName(fromPath: "/usr/sbin/mDNSResponder") == "mDNSResponder")
    }

    @Test func CPU_백분율_계산() {
        // 1초 동안 0.5초 사용 → 50%
        #expect(SystemResourceMonitor.cpuPercent(cpuDeltaNs: 500_000_000, elapsed: 1.0) == 50.0)
        // 멀티코어 폭주는 100% 초과 허용
        #expect(SystemResourceMonitor.cpuPercent(cpuDeltaNs: 2_000_000_000, elapsed: 1.0) == 200.0)
    }

    @Test func CPU_경과시간_0이면_nil() {
        #expect(SystemResourceMonitor.cpuPercent(cpuDeltaNs: 1_000, elapsed: 0) == nil)
        #expect(SystemResourceMonitor.cpuPercent(cpuDeltaNs: 1_000, elapsed: -1) == nil)
    }

    @Test func CPU_포맷() {
        #expect(SystemResourceMonitor.formatCPU(nil) == "–")
        #expect(SystemResourceMonitor.formatCPU(12.34) == "12.3%")
        #expect(SystemResourceMonitor.formatCPU(0) == "0.0%")
    }

    @Test func 메모리_포맷() {
        #expect(SystemResourceMonitor.formatMemory(2_147_483_648) == "2.0 GB")
        #expect(SystemResourceMonitor.formatMemory(100_000_000) == "95 MB")
        #expect(SystemResourceMonitor.formatMemory(500) == "0 KB")
    }

    @Test func 동일명_집계_CPU합산_RSS합산() {
        let agg = SystemResourceMonitor.aggregate(
            samples: [
                (name: "Safari", cpuDeltaNs: 500_000_000, rssBytes: 100),
                (name: "Safari", cpuDeltaNs: 500_000_000, rssBytes: 200),
                (name: "mDNSResponder", cpuDeltaNs: nil, rssBytes: 50),
            ],
            elapsed: 1.0, cpuCount: 8
        )
        #expect(agg.perName["Safari"]?.cpuPercent == 100.0)
        #expect(agg.perName["Safari"]?.rssBytes == 300)
        #expect(agg.perName["mDNSResponder"]?.cpuPercent == nil)
        #expect(agg.perName["mDNSResponder"]?.rssBytes == 50)
    }

    @Test func 시스템CPU_코어수_정규화() {
        // 총 8초분을 1초에 8코어로 → 100%
        let agg = SystemResourceMonitor.aggregate(
            samples: [(name: "a", cpuDeltaNs: 8_000_000_000, rssBytes: 0)],
            elapsed: 1.0, cpuCount: 8
        )
        #expect(agg.systemCPU == 100.0)
    }

    @Test func 첫샘플_시스템CPU_nil() {
        let agg = SystemResourceMonitor.aggregate(
            samples: [(name: "a", cpuDeltaNs: nil, rssBytes: 10)],
            elapsed: 0, cpuCount: 8
        )
        #expect(agg.systemCPU == nil)
        #expect(agg.perName["a"]?.cpuPercent == nil)
    }

    @Test func 전체랭킹_CPU순_nil꼴찌_동점이름순() {
        let map = [
            "node": ProcessResource(cpuPercent: 80, rssBytes: 100),
            "java": ProcessResource(cpuPercent: nil, rssBytes: 900),
            "a": ProcessResource(cpuPercent: 10, rssBytes: 10),
            "b": ProcessResource(cpuPercent: 10, rssBytes: 20),
        ]
        let top = SystemResourceMonitor.topResources(map, limit: 3) { $0.cpuPercent ?? -1 }
        #expect(top.map(\.name) == ["node", "a", "b"])
    }

    @Test func 전체랭킹_메모리순() {
        let map = [
            "node": ProcessResource(cpuPercent: 80, rssBytes: 100),
            "java": ProcessResource(cpuPercent: nil, rssBytes: 900),
        ]
        let top = SystemResourceMonitor.topResources(map, limit: 2) { Double($0.rssBytes) }
        #expect(top.map(\.name) == ["java", "node"])
    }

    @Test func 정렬키_raw값() {
        #expect(ResourceSort(rawValue: "network") == .network)
        #expect(ResourceSort(rawValue: "cpu") == .cpu)
        #expect(ResourceSort(rawValue: "memory") == .memory)
        #expect(ResourceSort(rawValue: "bogus") == nil)
    }
}
