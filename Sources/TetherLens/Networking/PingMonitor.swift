import Foundation
import Network

class PingMonitor: @unchecked Sendable {
    private var gatewayPingTask: Task<Void, Never>?
    private var dnsPingTask: Task<Void, Never>?

    private(set) var gatewayRTT: TimeInterval?
    private(set) var dnsRTT: TimeInterval?
    private(set) var isReachable: Bool = true
    private(set) var gatewayAddress: String?

    func start() {
        gatewayAddress = resolveGateway()
        dnsPingTask = Task { [weak self] in
            await self?.pingLoop(target: "8.8.8.8") { rtt in
                self?.dnsRTT = rtt
            }
        }
        if let gw = gatewayAddress {
            gatewayPingTask = Task { [weak self] in
                await self?.pingLoop(target: gw) { rtt in
                    self?.gatewayRTT = rtt
                }
            }
        }
    }

    func stop() {
        gatewayPingTask?.cancel()
        dnsPingTask?.cancel()
    }

    private func pingLoop(target: String, interval: TimeInterval = 2.0, callback: @escaping (TimeInterval?) -> Void) async {
        while !Task.isCancelled {
            let rtt = await performPing(host: target)
            callback(rtt)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func performPing(host: String) async -> TimeInterval? {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/sbin/ping"
            task.arguments = ["-c", "1", "-W", "2000", host]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0,
                   let line = output.components(separatedBy: "\n").first(where: { $0.contains("time=") }),
                   let msPart = line.components(separatedBy: "time=").last?.components(separatedBy: " ").first,
                   let ms = Double(msPart) {
                    continuation.resume(returning: ms / 1000.0)
                    return
                }
                continuation.resume(returning: nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private func resolveGateway() -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/route"
        task.arguments = ["-n", "get", "default"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            for line in output.components(separatedBy: "\n") {
                if line.contains("gateway:") {
                    return line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {}

        return nil
    }
}
