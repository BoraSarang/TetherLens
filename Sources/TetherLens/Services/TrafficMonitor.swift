import Foundation
import Combine

final class TrafficMonitor: ObservableObject, @unchecked Sendable {
    static let shared = TrafficMonitor()

    struct AppTraffic: Identifiable {
        let id: String
        let processName: String
        let bytesIn: Int64
        let bytesOut: Int64
        let totalBytesIn: Int64
        let totalBytesOut: Int64
    }

    @Published private(set) var apps: [AppTraffic] = []

    private var timer: Timer?
    private var saveTimer: Timer?
    private var accumulated: [String: (in: Int64, out: Int64)] = [:]
    private var lastSavedAccumulated: [String: (in: Int64, out: Int64)] = [:]
    private var isRefreshing = false
    private let queue = DispatchQueue(label: "com.tetherlens.traffic", qos: .utility)

    private init() {}

    func start() {
        // accumulated은 반드시 queue 안에서만 접근 (refresh와의 data race 방지).
        // serial queue FIFO로 리셋 → 이후 refresh 순서가 보장된다.
        queue.async { [weak self] in
            self?.accumulated = [:]
            self?.lastSavedAccumulated = [:]
        }
        refresh()
        let refreshTimer = Timer(timeInterval: SettingsManager.shared.trafficMonitorInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(refreshTimer, forMode: .common)
        timer = refreshTimer
        let saveTimer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            self?.saveAccumulated()
        }
        RunLoop.main.add(saveTimer, forMode: .common)
        self.saveTimer = saveTimer
    }

    func stop() {
        saveTimer?.invalidate()
        saveTimer = nil
        timer?.invalidate()
        timer = nil
        saveAccumulated()
        queue.async { [weak self] in
            self?.accumulated = [:]
            self?.lastSavedAccumulated = [:]
            DispatchQueue.main.async { [weak self] in
                self?.apps = []
            }
        }
    }

    /// 앱 종료 시 마지막 구간 로그 유실을 막기 위한 동기 flush.
    /// queue.sync로 nettop 점유 작업이 끝날 때까지 대기하므로 종료 시점에만 호출해야 한다.
    func flushBeforeTermination() {
        queue.sync { [weak self] in
            self?.persistAccumulated()
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
            let result = self.parse(output)

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
                apps.append(AppTraffic(
                    id: name,
                    processName: name,
                    bytesIn: currentBytes.bytesIn,
                    bytesOut: currentBytes.bytesOut,
                    totalBytesIn: acc.in,
                    totalBytesOut: acc.out
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
                self?.apps = apps
            }
        }
    }

    private func runNettop() -> String {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-J", "bytes_in,bytes_out", "-x", "-d", "-l", "2", "-n", "-s", "1"]
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
        DispatchQueue.global().asyncAfter(deadline: .now() + 15) { [weak task] in
            if task?.isRunning == true {
                task?.terminate()
            }
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parse(_ output: String) -> [(name: String, bytesIn: Int64, bytesOut: Int64)] {
        let lines = output.components(separatedBy: .newlines)
        var current: [(String, Int64, Int64)] = []
        var last: [(String, Int64, Int64)] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("time") {
                if !current.isEmpty {
                    last = current
                    current = []
                }
                continue
            }
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 4 else { continue }
            let procPid = parts[1]
            let name = procPid.components(separatedBy: ".").dropLast().joined(separator: ".")
            let downloadBytes = Int64(parts[parts.count - 2]) ?? 0
            let uploadBytes = Int64(parts[parts.count - 1]) ?? 0
            current.append((name.isEmpty ? procPid : name, uploadBytes, downloadBytes))
        }
        if !current.isEmpty { last = current }
        return last
    }
}
