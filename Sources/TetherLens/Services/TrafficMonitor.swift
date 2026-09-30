import Foundation
import Combine

final class TrafficMonitor: ObservableObject, @unchecked Sendable {
    static let shared = TrafficMonitor()

    /// TrafficMonitor를 활성 상태로 끌어올리는 소비자 구분 (에너지 최적화 — 지연 시작).
    enum Usage {
        case popover, sheet, appBlock, floating
    }

    struct AppTraffic: Identifiable {
        let id: String
        let processName: String
        let bytesIn: Int64
        let bytesOut: Int64
        let totalBytesIn: Int64
        let totalBytesOut: Int64
        /// libproc 델타 기반 CPU% (1코어=100%). 첫 샘플 주기는 nil.
        var cpuPercent: Double? = nil
        /// RSS 합산 바이트. 조회 실패 시 0.
        var memBytes: Int64 = 0
    }

    /// refresh 1틱마다 단일 스냅샷으로 갱신 — 이전 3×@Published 무효화 통합 (v0.38.1)
    struct Snapshot {
        var apps: [AppTraffic] = []
        var systemLoad: SystemLoad?
        var allResources: [String: ProcessResource] = [:]
    }

    @Published private(set) var snapshot = Snapshot()

    var apps: [AppTraffic] { snapshot.apps }
    /// 시스템 전체 부하 요약 (헤더 표시용, v0.32).
    var systemLoad: SystemLoad? { snapshot.systemLoad }
    /// 전체 프로세스 리소스 스냅샷 — 네트워크 무관 CPU/RAM 랭킹용 (v0.32.4).
    var allResources: [String: ProcessResource] { snapshot.allResources }

    private var timer: Timer?
    private var saveTimer: Timer?
    private var accumulated: [String: (in: Int64, out: Int64)] = [:]
    private var lastSavedAccumulated: [String: (in: Int64, out: Int64)] = [:]
    private var isRefreshing = false
    private let queue = DispatchQueue(label: "com.tetherlens.traffic", qos: .utility)

    /// 진행 중인 nettop 프로세스 — **queue 안에서만** 접근한다.
    /// 종료 시 즉시 죽여 큐 점유를 해제하기 위한 핸들.
    private var activeTask: Process?

    // 지연 시작 상태 — 모두 main actor 스레드에서 접근해 NSLock 없이 유지한다.
    private var usageRefs: [Usage: Bool] = [:]
    private var lowPowerOverride = false
    private var isRunning = false
    // acquire/release 불균형(누수) 탐지용 카운터 — Release 로그와 함께 출력한다.
    private var usageBalance = 0

    private init() {}

    /// 소비자가 필요해질 때 호출 — 첫 참조가 생기면 실제 start()를 수행한다.
    func acquire(reason: Usage) {
        let wasActive = isAnyUsageActive
        usageRefs[reason] = true
        usageBalance += 1
        evaluateIfNeeded(wasActive: wasActive)
        Task { @MainActor in
            DebugLogger.shared.action("Traffic", "acquire(\(reason)) → active=\(isAnyUsageActive) running=\(isRunning) balance=\(usageBalance)")
        }
    }

    /// 소비자가 더 이상 보지 않을 때 호출 — 마지막 참조가 사라지면 실제 stop()을 수행한다.
    func release(reason: Usage) {
        let wasActive = isAnyUsageActive
        usageRefs[reason] = false
        usageBalance -= 1
        evaluateIfNeeded(wasActive: wasActive)
        Task { @MainActor in
            DebugLogger.shared.action("Traffic", "release(\(reason)) → active=\(isAnyUsageActive) running=\(isRunning) balance=\(usageBalance)")
        }
    }

    /// 앱 종료/모니터링 중지 — 모든 참조를 비우고 실제 중지한다.
    func resetAllUsage() {
        usageRefs = [:]
        usageBalance = 0
        lowPowerOverride = false
        if isRunning {
            stopLocked()
            isRunning = false
        }
    }

    /// 저전력 모드 전환 시 호출 — 활성 참조가 있어도 강제 중지/재개한다.
    func setLowPower(_ enabled: Bool) {
        guard lowPowerOverride != enabled else { return }
        lowPowerOverride = enabled
        if enabled {
            if isRunning { stopLocked(); isRunning = false }
        } else {
            if isAnyUsageActive, !isRunning { start(); isRunning = true }
        }
        Task { @MainActor in
            DebugLogger.shared.system("Power", "저전력 \(enabled ? "ON" : "OFF") - TrafficMonitor \(enabled ? "중지" : "재개")")
        }
    }

    /// 시스템 슬립 등 일시 중지 — 참조 상태는 유지하고 중지만 수행한다.
    func suspend() {
        guard isRunning else { return }
        stopLocked()
        isRunning = false
    }

    /// 시스템 깨어남 등 재개 — 활성 참조가 있으면 재시작한다.
    func resume() {
        if isAnyUsageActive, !lowPowerOverride, !isRunning {
            start()
            isRunning = true
        }
    }

    private var isAnyUsageActive: Bool {
        usageRefs.values.contains { $0 }
    }

    private func evaluateIfNeeded(wasActive: Bool) {
        let activeNow = isAnyUsageActive && !lowPowerOverride
        if activeNow, !wasActive, !isRunning {
            start()
            isRunning = true
        } else if !activeNow, wasActive, isRunning {
            stopLocked()
            isRunning = false
        }
    }

    private func start() {
        // accumulated은 반드시 queue 안에서만 접근 (refresh와의 data race 방지).
        // serial queue FIFO로 리셋 → 이후 refresh 순서가 보장된다.
        queue.async { [weak self] in
            self?.accumulated = [:]
            self?.lastSavedAccumulated = [:]
        }
        refresh()
        scheduleNextRefresh()
        Task { @MainActor in
            DebugLogger.shared.info("SysRes", "CPU/MEM 병합 시작 — nettop 주기 편승 (추가 타이머 없음)")
        }
        let saveTimer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            self?.saveAccumulated()
        }
        saveTimer.tolerance = 30 // 300초 주기의 10%
        RunLoop.main.add(saveTimer, forMode: .common)
        self.saveTimer = saveTimer
    }

    /// refresh 완료 후 interval 뒤 다시 예약해, nettop 실행 시간과 타이머가 겹치지 않게 한다.
    /// (반복 타이머면 nettop 블로킹 동안 틱이 백로그되어 측정 간격이 어긋난다)
    private func scheduleNextRefresh() {
        timer?.invalidate()
        let interval = max(SettingsManager.shared.trafficMonitorInterval, 1)
        let refreshTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
            self?.scheduleNextRefresh()
        }
        // 단발 그러나 반복 재예약 — 재예약 주기의 10% 허용 오차로 타이머 병합
        refreshTimer.tolerance = max(interval * 0.1, 0.05)
        RunLoop.main.add(refreshTimer, forMode: .common)
        timer = refreshTimer
    }

    private func stopLocked() {
        saveTimer?.invalidate()
        saveTimer = nil
        timer?.invalidate()
        timer = nil
        saveAccumulated()
        queue.async { [weak self] in
            self?.accumulated = [:]
            self?.lastSavedAccumulated = [:]
            DispatchQueue.main.async { [weak self] in
                self?.snapshot = Snapshot()
            }
        }
    }

    /// 앱 종료 시 마지막 구간 로그 유실을 막기 위한 flush.
    ///
    /// ⚠️ nettop 은 `-l <interval>` 만큼(기본 10초, 최대 30초) serial queue 를 점유한다.
    /// 예전처럼 `queue.sync` 만 걸면 메인 스레드(종료 알림)가 그만큼 블로킹돼
    /// 앱이 종료되지 않는 것처럼 보였다 (T-250 #3).
    /// 진행 중인 nettop 을 먼저 죽여 큐를 비우고, 그래도 안 비면 상한 시간만 기다린다.
    func flushBeforeTermination() {
        // serial queue 는 FIFO — 아래 종료 블록이 flush 보다 **먼저** 실행된다.
        queue.async { [weak self] in
            self?.activeTask?.terminate()
        }
        let done = DispatchSemaphore(value: 0)
        queue.async { [weak self] in
            self?.persistAccumulated()
            done.signal()
        }
        // 이미 큐에 들어간 저장은 신호가 오지 않아도 실행된다. 여기서는
        // 메인 스레드가 무한정 붙잡히지 않을 상한만 정한다.
        if done.wait(timeout: .now() + 2.0) == .timedOut {
            Task { @MainActor in
                DebugLogger.shared.info("Traffic", "종료 flush 상한 초과 — 저장만 미완료(앱 종료 지연 방지)")
            }
        }
    }

    func resetAccumulated() {
        queue.async { [weak self] in
            self?.accumulated = [:]
            self?.lastSavedAccumulated = [:]
        }
    }

    private func saveAccumulated() {
        queue.async { [weak self] in
            self?.persistAccumulated()
        }
    }

    private func persistAccumulated() {
        let now = Date()
        var logs: [AppTrafficLog] = []
        for (name, current) in accumulated {
            let last = lastSavedAccumulated[name, default: (0, 0)]
            let uploadDelta = current.in - last.in
            let downloadDelta = current.out - last.out
            if uploadDelta > 0 || downloadDelta > 0 {
                logs.append(AppTrafficLog(
                    id: UUID(),
                    processName: name,
                    uploadBytes: uploadDelta,
                    downloadBytes: downloadDelta,
                    recordedAt: now
                ))
            }
        }
        lastSavedAccumulated = accumulated
        guard !logs.isEmpty else { return }
        do {
            try DataStore.shared.dbQueue.write { db in
                for log in logs {
                    try log.insert(db)
                }
            }
        } catch {
            let msg = "트래픽 로그 저장 실패: \(error.localizedDescription)"
            DispatchQueue.main.async { DebugLogger.shared.error("Traffic", msg) }
        }
    }

    private func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            // nettop(~2초) 블로킹 동안 쌓인 중복 refresh는 skip해 백로그 방지
            guard !self.isRefreshing else { return }
            self.isRefreshing = true
            defer { self.isRefreshing = false }

            let output = self.runNettop()
            let result = Self.parse(output)
            // CPU/MEM은 같은 주기에 편승해 1회만 조회한다 (추가 wakeup 없음, v0.32).
            let resources = SystemResourceMonitor.shared.fetchResources()

            for entry in result {
                var current = self.accumulated[entry.name, default: (0, 0)]
                current.in += entry.bytesIn
                current.out += entry.bytesOut
                self.accumulated[entry.name] = current
            }

            var merged: [String: (bytesIn: Int64, bytesOut: Int64)] = [:]
            for entry in result {
                let current = merged[entry.name, default: (0, 0)]
                merged[entry.name] = (current.bytesIn + entry.bytesIn, current.bytesOut + entry.bytesOut)
            }

            var apps: [AppTraffic] = []
            for (name, currentBytes) in merged {
                let acc = self.accumulated[name, default: (0, 0)]
                let res = resources.perName[name]
                apps.append(AppTraffic(
                    id: name,
                    processName: name,
                    bytesIn: currentBytes.bytesIn,
                    bytesOut: currentBytes.bytesOut,
                    totalBytesIn: acc.in,
                    totalBytesOut: acc.out,
                    cpuPercent: res?.cpuPercent,
                    memBytes: res?.rssBytes ?? 0
                ))
            }
            let blockedCandidates = merged.filter { $0.value.bytesIn > 0 || $0.value.bytesOut > 0 }
            DispatchQueue.main.async {
                for (name, current) in blockedCandidates {
                    AppBlockManager.shared.check(name, bytesIn: current.bytesIn, bytesOut: current.bytesOut)
                }
            }
            apps = apps.filter { $0.bytesIn > 0 || $0.bytesOut > 0 || $0.totalBytesIn > 0 || $0.totalBytesOut > 0 }
            apps.sort { $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut }

            DispatchQueue.main.async { [weak self] in
                var next = self?.snapshot ?? Snapshot()
                next.apps = apps
                next.systemLoad = resources.system
                next.allResources = resources.perName
                self?.snapshot = next // 단일 objectWillChange (v0.38.1)
                // v0.37 — 시스템 CPU/GPU/MEM 스파크라인 히스토리 (refresh 편승, 추가 타이머 없음)
                MetricsHistory.shared.push(system: resources.system)
            }
        }
    }

    private func runNettop() -> String {
        // 측정 윈도우는 재조회 주기와 맞춰야 누적값이 정확하다.
        // 이전엔 `-l 2`(1초) 고정이라 기본 10초 주기 중 1초만 측정해
        // 표시값과 app_traffic_log 총합이 실제 전송량의 약 1/10로 과소 계상되었다.
        // nettop은 샘플 1개당 1초가 걸리므로 samples == interval로 두면 전 구간을 커버한다.
        // (TrafficMonitor는 참조 카운팅으로 소비자가 보일 때만 돌므로 부하도 그 구간으로 제한된다)
        let interval = max(SettingsManager.shared.trafficMonitorInterval, 1)
        let samples = max(2, min(Int(interval.rounded()), 30))
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-J", "bytes_in,bytes_out", "-x", "-d", "-l", "\(samples)", "-n", "-s", "1"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            Task { @MainActor in
                DebugLogger.shared.error("Traffic", "nettop 실행 실패: \(error.localizedDescription)")
            }
            return ""
        }
        activeTask = task  // 종료 시 terminate() 로 큐 점해를 빨리 끝내기 위함
        DispatchQueue.global().asyncAfter(deadline: .now() + Double(samples + 5)) { [weak task] in
            if task?.isRunning == true {
                task?.terminate()
            }
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        activeTask = nil
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// nettop 출력의 모든 델타 블록을 합산한다.
    ///
    /// `-d` 델타 모드의 첫 블록은 기준점(모두 0)이고, 이후 블록이 1초 구간별 델타다.
    /// 마지막 블록만 쓰면 그 이전 구간이 통째로 사라지므로 전 블록을 합산한다.
    ///
    /// nettop 컬럼 순서는 `time process.pid bytes_in bytes_out` 이고,
    /// 반환 튜플의 bytesIn 슬롯이 UI에서 업로드로 표시되므로(AppTrafficView가 TLPalette.upload 사용)
    /// 이 대응을 유지한다.
    static func parse(_ output: String) -> [(name: String, bytesIn: Int64, bytesOut: Int64)] {
        var totals: [String: (bytesIn: Int64, bytesOut: Int64)] = [:]

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("time") { continue }  // 블록 헤더
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 4 else { continue }
            // 프로세스명은 공백을 포함할 수 있다("OpenCode Helper.56898").
            // 따라서 첫 칸만 떼어내지 않고 시간 컬럼과 마지막 2개 바이트 컬럼 사이를 전부 이름으로 묶은 뒤
            // 끝에 붙은 PID(마지막 점 성분)만 제거한다.
            let nameWithPid = parts[1..<(parts.count - 2)].joined(separator: " ")
            let name = nameWithPid.components(separatedBy: ".").dropLast().joined(separator: ".")
            let key = name.isEmpty ? nameWithPid : name
            let bytesIn = Int64(parts[parts.count - 1]) ?? 0
            let bytesOut = Int64(parts[parts.count - 2]) ?? 0
            var acc = totals[key] ?? (0, 0)
            acc.bytesIn += bytesIn
            acc.bytesOut += bytesOut
            totals[key] = acc
        }

        return totals.map { (name: $0.key, bytesIn: $0.value.bytesIn, bytesOut: $0.value.bytesOut) }
    }
}
