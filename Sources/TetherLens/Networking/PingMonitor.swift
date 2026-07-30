import Foundation
import Network
import UserNotifications

class PingMonitor: @unchecked Sendable {
    private var task: Task<Void, Never>?

    private(set) var gatewayRTT: TimeInterval?
    private(set) var dnsRTT: TimeInterval?
    private(set) var isReachable: Bool = true
    private(set) var gatewayAddress: String?

    var isHotspot: Bool = false

    private var lastReachable: Bool = true
    private var lastAlertTime: Date?
    private var lastAlertLevel: Int = 0
    private var lastNotifiedLevel: Int = 0

    private var dnsHistory: [TimeInterval?] = []
    private var gatewayHistory: [TimeInterval?] = []
    private let historySize = 20
    private var consecutiveViolations: Int = 0
    private var sustainedStart: Date?
    private var recoveryStart: Date?

    private let warningThreshold: TimeInterval = 0.1
    private let criticalThreshold: TimeInterval = 0.25
    private let gatewayWarningThreshold: TimeInterval = 0.05
    private let gatewayCriticalThreshold: TimeInterval = 0.08
    private let sustainedDuration: TimeInterval = 10.0
    private let cooldownDuration: TimeInterval = 120.0
    private let recoveryDuration: TimeInterval = 10.0
    private let consecutiveCount = 5
    private let packetLossThreshold = 0.1

    private let notiCenter = UNUserNotificationCenter.current()

    func start() {
        gatewayAddress = resolveGateway()
        task = Task { [weak self] in
            await self?.pingLoop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func resetState() {
        lastAlertTime = nil
        lastAlertLevel = 0
        lastNotifiedLevel = 0
        consecutiveViolations = 0
        sustainedStart = nil
        recoveryStart = nil
        dnsHistory.removeAll()
        gatewayHistory.removeAll()
    }

    private func pingLoop() async {
        let interval = SettingsManager.shared.pingInterval
        var useDNS = true
        while !Task.isCancelled {
            let target = useDNS ? "8.8.8.8" : (gatewayAddress ?? "8.8.8.8")
            let rtt = await performPing(host: target)
            if useDNS {
                dnsRTT = rtt
            } else {
                gatewayRTT = rtt
            }
            isReachable = (dnsRTT ?? 1) < 2.0 || (gatewayRTT ?? 1) < 2.0
            if useDNS {
                await checkAndNotify()
            }
            useDNS.toggle()
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func checkAndNotify() async {
        let wasReachable = lastReachable
        lastReachable = isReachable

        if isReachable != wasReachable {
            lastAlertLevel = 0
            lastNotifiedLevel = 0
            consecutiveViolations = 0
            sustainedStart = nil
            recoveryStart = nil
            if isReachable {
                await postPingAlert(type: .connectionRestored, level: 0, message: Localized.connectionRestored)
            } else {
                await postPingAlert(type: .connectionLost, level: 0, message: Localized.connectionLost)
            }
            return
        }

        guard isReachable else { return }

        dnsHistory.append(dnsRTT)
        if dnsHistory.count > historySize { dnsHistory.removeFirst() }
        gatewayHistory.append(gatewayRTT)
        if gatewayHistory.count > historySize { gatewayHistory.removeFirst() }

        guard isHotspot else { return }
        guard SettingsManager.shared.pingLatencyNotificationEnabled else {
            lastAlertLevel = 0
            lastNotifiedLevel = 0
            consecutiveViolations = 0
            sustainedStart = nil
            recoveryStart = nil
            return
        }

        let currentLevel = classifyLatency()
        let hasPacketLoss = checkPacketLoss()

        if currentLevel > 0 || hasPacketLoss {
            consecutiveViolations += 1
            if sustainedStart == nil {
                sustainedStart = Date()
            }
        } else {
            consecutiveViolations = 0
            sustainedStart = nil
        }

        let sustained = checkSustained()
        let inCooldown = checkCooldown(level: currentLevel)

        if currentLevel == 0 && !hasPacketLoss && lastAlertLevel > 0 {
            if recoveryStart == nil {
                recoveryStart = Date()
            }
            if Date().timeIntervalSince(recoveryStart!) >= recoveryDuration {
                let msg = "\(Localized.pingRecoveryTitle)\n\(Localized.pingRecoveryBody)"
                await postPingAlert(type: .pingRecovery, level: 0, message: msg)
                lastAlertLevel = 0
                lastNotifiedLevel = 0
                recoveryStart = nil
                consecutiveViolations = 0
                sustainedStart = nil
            }
        } else if currentLevel > 0 || hasPacketLoss {
            recoveryStart = nil
        }

        guard sustained, !inCooldown, currentLevel > 0, currentLevel != lastNotifiedLevel else {
            if currentLevel == 0 {
                lastNotifiedLevel = 0
            }
            return
        }

        let msg = buildMessage(level: currentLevel)
        let type: AppNotification.NotificationType = currentLevel == 2 ? .pingCritical : .pingWarning
        await postPingAlert(type: type, level: currentLevel, message: msg)
        lastAlertLevel = currentLevel
        lastNotifiedLevel = currentLevel
        lastAlertTime = Date()
        recoveryStart = nil
    }

    private func classifyLatency() -> Int {
        let dns = dnsRTT ?? 999
        let gw = gatewayRTT ?? 999

        if dns >= criticalThreshold { return 2 }
        if gw >= gatewayCriticalThreshold { return 2 }
        if dns >= warningThreshold { return 1 }
        if gw >= gatewayWarningThreshold { return 1 }
        return 0
    }

    private func checkPacketLoss() -> Bool {
        let window = min(dnsHistory.count, 10)
        guard window >= 5 else { return false }
        let recent = dnsHistory.suffix(window)
        let lossCount = recent.filter { $0 == nil }.count
        let ratio = Double(lossCount) / Double(window)
        return ratio >= packetLossThreshold
    }

    private func checkSustained() -> Bool {
        if consecutiveViolations >= consecutiveCount { return true }
        if let start = sustainedStart {
            if Date().timeIntervalSince(start) >= sustainedDuration { return true }
        }
        return false
    }

    private func checkCooldown(level: Int) -> Bool {
        guard let lastTime = lastAlertTime else { return false }
        return Date().timeIntervalSince(lastTime) < cooldownDuration
    }

    private func buildMessage(level: Int) -> String {
        let dns = Int((dnsRTT ?? 0) * 1000)
        let gw = Int((gatewayRTT ?? 0) * 1000)

        if level == 2 {
            if dns >= 250 {
                return "\(Localized.pingCriticalTitle)\n\(Localized.pingCriticalBody(dns))"
            }
            return "\(Localized.pingUnstableTitle)\n\(Localized.pingUnstableBody(gw))"
        }

        return "\(Localized.pingWarningTitle)\n\(Localized.pingWarningBody(dns))"
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

    private func postPingAlert(type: AppNotification.NotificationType, level: Int, message: String) async {
        NotificationManager.shared.add(type: type, message: message)
        NotificationCenter.default.post(name: .init("pingAlert"), object: nil, userInfo: [
            "message": message,
            "type": type.rawValue,
            "level": level
        ])
        let content = UNMutableNotificationContent()
        content.title = "TetherLens"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "ping-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await notiCenter.add(request)
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
