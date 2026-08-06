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
    private let queue = DispatchQueue(label: "com.tetherlens.traffic", qos: .utility)

    private init() {}

    func start() {
        accumulated = [:]
        lastSavedAccumulated = [:]
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: SettingsManager.shared.trafficMonitorInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        saveTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.saveAccumulated()
        }
    }

    func stop() {
        saveAccumulated()
        saveTimer?.invalidate()
        saveTimer = nil
        timer?.invalidate()
        timer = nil
        accumulated = [:]
        DispatchQueue.main.async { [weak self] in
            self?.apps = []
        }
    }

    func resetAccumulated() {
        queue.async { [weak self] in
            self?.accumulated = [:]
        }
    }

    private func saveAccumulated() {
        queue.async { [weak self] in
            guard let self else { return }
            let now = Date()
            var logs: [AppTrafficLog] = []
            for (name, current) in self.accumulated {
                let last = self.lastSavedAccumulated[name, default: (0, 0)]
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
            self.lastSavedAccumulated = self.accumulated
            guard !logs.isEmpty else { return }
            try! DataStore.shared.dbQueue.write { db in
                for log in logs {
                    try log.insert(db)
                }
            }
        }
    }

    private func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
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
                AppBlockManager.shared.check(
                    name,
                    bytesIn: currentBytes.bytesIn,
                    bytesOut: currentBytes.bytesOut
                )
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
        task.launch()
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
