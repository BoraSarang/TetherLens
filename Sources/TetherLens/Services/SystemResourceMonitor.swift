import Foundation

/// 프로세스별 CPU/MEM 보조 지표를 수집한다 (v0.32).
/// - 서브프로세스(`ps`/`top`)를 띄우지 않고 `libproc` + `host_statistics64`를 직접 호출한다.
/// - 별도 타이머를 갖지 않는다 — `TrafficMonitor.refresh()` 직렬 queue에서만 호출되어
///   wakeup 추가 없이 기존 nettop 주기(기본 10초)에 편승한다. 저전력/슬립 가드는 호출 측이 상속.
/// - CPU%는 `pti_total_user + pti_total_system`(ns) 델타 기반이라 첫 샘플은 `nil`(다음 주기부터 표시).
enum ResourceSort: String, CaseIterable {
    case network, cpu, memory
}

struct ProcessResource {
    /// 1코어=100% 기준 (`top`과 동일 정의, 멀티코어 시 100% 초과 가능). 첫 샘플은 nil.
    let cpuPercent: Double?
    /// RSS 합산 (동일 프로세스명 다중 pid 합산).
    let rssBytes: Int64
}

struct SystemLoad {
    let cpuTotalPercent: Double?
    /// -1이면 조회 실패 (표시 "–").
    let memUsedBytes: Int64
    let memTotalBytes: Int64
}

struct ResourceSnapshot {
    let perName: [String: ProcessResource]
    let system: SystemLoad
}

final class SystemResourceMonitor: @unchecked Sendable {
    static let shared = SystemResourceMonitor()

    /// 이전 fetch의 pid별 누적 CPU 시간(ns) + fetch 시각 — 호출 측 직렬 queue에서만 접근한다.
    private var prevTotals: [Int32: UInt64] = [:]
    private var prevAt: Date?
    private var samplingErrorLogged = false

    init() {}

    // MARK: - Live sampling (호출 측 직렬 queue 전용)

    func fetchResources(now: Date = Date()) -> ResourceSnapshot {
        let memTotal = Int64(ProcessInfo.processInfo.physicalMemory)
        let pids = Self.listPids()
        guard !pids.isEmpty else {
            logSamplingError("E-MAC-PERF-3201 리소스 샘플링 실패: pid 목록 조회 실패")
            return ResourceSnapshot(
                perName: [:],
                system: SystemLoad(cpuTotalPercent: nil, memUsedBytes: -1, memTotalBytes: memTotal)
            )
        }

        var perPid: [(pid: Int32, name: String, totalNs: UInt64, rss: Int64)] = []
        perPid.reserveCapacity(pids.count)
        for pid in pids {
            guard let sample = Self.samplePid(pid) else { continue }
            perPid.append((pid: pid, name: sample.name, totalNs: sample.totalNs, rss: sample.rss))
        }
        let named = perPid
        let elapsed = prevAt.map { now.timeIntervalSince($0) }
        let prev = prevTotals

        var deltas: [(name: String, cpuDeltaNs: UInt64?, rssBytes: Int64)] = []
        deltas.reserveCapacity(named.count)
        var nextTotals: [Int32: UInt64] = [:]
        nextTotals.reserveCapacity(named.count)
        for entry in named {
            nextTotals[entry.pid] = entry.totalNs
            var delta: UInt64?
            if let e = elapsed, e > 0.01, let old = prev[entry.pid], entry.totalNs >= old {
                delta = entry.totalNs - old
            }
            deltas.append((name: entry.name, cpuDeltaNs: delta, rssBytes: entry.rss))
        }
        prevTotals = nextTotals
        prevAt = now

        let elapsedValue = elapsed ?? 0
        let aggregated = Self.aggregate(
            samples: deltas, elapsed: elapsedValue,
            cpuCount: max(ProcessInfo.processInfo.processorCount, 1)
        )
        let memUsed = Self.hostMemUsedBytes() ?? -1
        if memUsed < 0 {
            logSamplingError("E-MAC-PERF-3201 리소스 샘플링 실패: 메모리 통계 조회 실패")
        } else {
            samplingErrorLogged = false
        }
        if elapsed == nil {
            Task { @MainActor in
                DebugLogger.shared.info("SysRes", "CPU 기준 샘플 저장 — 다음 주기부터 % 표시")
            }
        }
        return ResourceSnapshot(
            perName: aggregated.perName,
            system: SystemLoad(
                cpuTotalPercent: aggregated.systemCPU,
                memUsedBytes: memUsed, memTotalBytes: memTotal
            )
        )
    }

    // MARK: - Pure helpers (단위 테스트 대상)

    /// nettop `Foo.1234` → `Foo`. 숫자 pid 접미사가 없으면 그대로.
    static func stripPidSuffix(_ raw: String) -> String {
        guard let dot = raw.lastIndex(of: ".") else { return raw }
        let suffix = raw[raw.index(after: dot)...]
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isNumber }) else { return raw }
        let base = String(raw[..<dot])
        return base.isEmpty ? raw : base
    }

    /// `/Applications/Safari.app/…/Safari` → `Safari`.
    static func baseName(fromPath path: String) -> String {
        (path as NSString).lastPathComponent
    }

    /// CPU 델타(ns) → %. elapsed가 너무 짧으면 nil.
    static func cpuPercent(cpuDeltaNs: UInt64, elapsed: TimeInterval) -> Double? {
        guard elapsed > 0.01 else { return nil }
        return Double(cpuDeltaNs) / 1_000_000_000.0 / elapsed * 100.0
    }

    static func formatCPU(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.1f%%", value)
    }

    static func formatMemory(_ bytes: Int64) -> String {
        let b = Double(max(bytes, 0))
        if b >= 1_073_741_824 {
            return String(format: "%.1f GB", b / 1_073_741_824)
        } else if b >= 1_048_576 {
            return String(format: "%.0f MB", b / 1_048_576)
        } else {
            return String(format: "%.0f KB", b / 1_024)
        }
    }

    /// 전체 스냅샷에서 값 기준 Top N (동점 시 이름순 — 표시 안정용).
    /// CPU는 nil(첫 주기)을 가장 낮게 취급하므로 `$0.cpuPercent ?? -1` 형태로 넘긴다.
    static func topResources(
        _ map: [String: ProcessResource],
        limit: Int,
        value: (ProcessResource) -> Double
    ) -> [(name: String, res: ProcessResource)] {
        map.sorted {
            let a = value($0.value), b = value($1.value)
            if a != b { return a > b }
            return $0.key < $1.key
        }
        .prefix(limit)
        .map { (name: $0.key, res: $0.value) }
    }
    /// pid별 샘플을 프로세스명으로 집계한다. 동일명 다중 pid는 CPU 합산(전부 nil이면 nil)·RSS 합산.
    static func aggregate(
        samples: [(name: String, cpuDeltaNs: UInt64?, rssBytes: Int64)],
        elapsed: TimeInterval,
        cpuCount: Int
    ) -> (perName: [String: ProcessResource], systemCPU: Double?) {
        var cpuSum: [String: Double] = [:]
        var cpuSeen: Set<String> = []
        var rssSum: [String: Int64] = [:]
        var totalDelta: UInt64 = 0
        var totalSeen = false
        for s in samples {
            rssSum[s.name, default: 0] += s.rssBytes
            if let d = s.cpuDeltaNs, let pct = cpuPercent(cpuDeltaNs: d, elapsed: elapsed) {
                cpuSum[s.name, default: 0] += pct
                cpuSeen.insert(s.name)
                totalDelta += d
                totalSeen = true
            }
        }
        var perName: [String: ProcessResource] = [:]
        for (name, rss) in rssSum {
            perName[name] = ProcessResource(
                cpuPercent: cpuSeen.contains(name) ? cpuSum[name] : nil,
                rssBytes: rss
            )
        }
        let systemCPU: Double?
        if totalSeen, let pct = cpuPercent(cpuDeltaNs: totalDelta, elapsed: elapsed) {
            systemCPU = pct / Double(max(cpuCount, 1))
        } else {
            systemCPU = nil
        }
        return (perName, systemCPU)
    }

    // MARK: - Darwin plumbing

    private static func listPids() -> [Int32] {
        let needed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard needed > 0 else { return [] }
        let maxCount = Int(needed) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: maxCount)
        let got: Int32 = pids.withUnsafeMutableBytes { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return 0 }
            return proc_listpids(UInt32(PROC_ALL_PIDS), 0, base, Int32(ptr.count))
        }
        guard got > 0 else { return [] }
        return Array(pids.prefix(Int(got) / MemoryLayout<pid_t>.size))
    }

    private static func samplePid(_ pid: Int32) -> (name: String, totalNs: UInt64, rss: Int64)? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let ret: Int32 = withUnsafeMutableBytes(of: &info) { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return proc_pidinfo(pid, Int32(PROC_PIDTASKINFO), 0, base, size)
        }
        guard ret == size else { return nil }
        let total = info.pti_total_user + info.pti_total_system
        let rss = Int64(info.pti_resident_size)
        if let path = pidPath(pid), !path.isEmpty {
            let name = baseName(fromPath: path)
            if !name.isEmpty { return (name, total, rss) }
        }
        let short = procComm(pid)
        guard !short.isEmpty else { return nil }
        return (short, total, rss)
    }

    private static func pidPath(_ pid: Int32) -> String? {
        // PROC_PIDPATHINFO_MAXSIZE(=4*MAXPATHLEN)는 산술 매크로라 Swift로 노출되지 않아 리터럴 사용.
        var buf = [CChar](repeating: 0, count: 4096)
        let len: Int32 = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return 0 }
            return proc_pidpath(pid, base, UInt32(ptr.count))
        }
        guard len > 0 else { return nil }
        return String(cString: buf)
    }

    private static func procComm(_ pid: Int32) -> String {
        var buf = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        let len: Int32 = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return 0 }
            return proc_name(pid, base, UInt32(ptr.count))
        }
        guard len > 0 else { return "" }
        return String(cString: buf)
    }

    /// Activity Monitor의 "사용된 메모리" 근사치 (active + wired + compressed).
    private static func hostMemUsedBytes() -> Int64? {
        var vmInfo = vm_statistics64()
        var count = mach_msg_type_number_t(
            UInt32(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        )
        let kr: kern_return_t = withUnsafeMutablePointer(to: &vmInfo) { vmPtr in
            vmPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }
        let pages = UInt64(vmInfo.active_count) + UInt64(vmInfo.wire_count) + UInt64(vmInfo.compressor_page_count)
        return Int64(pages * UInt64(pageSize))
    }

    // MARK: - Logging

    /// 실패 로그는 복구될 때까지 1회만 출력한다 (10초 주기 스팸 방지).
    private func logSamplingError(_ message: String) {
        guard !samplingErrorLogged else { return }
        samplingErrorLogged = true
        Task { @MainActor in
            DebugLogger.shared.error("SysRes", message)
        }
    }
}
