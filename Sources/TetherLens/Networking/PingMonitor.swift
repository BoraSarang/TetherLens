import Foundation
import Network
import UserNotifications

@MainActor
class PingMonitor {
    private var task: Task<Void, Never>?
    private var gatewayTask: Task<Void, Never>?

    private(set) var gatewayRTT: TimeInterval?
    private(set) var dnsRTT: TimeInterval?
    private(set) var isReachable: Bool = true
    private(set) var gatewayAddress: String?

    /// 핫스팟 품질 판단에 쓰이는 대표 지연 — 게이트웨이(폰) 우선, 없으면 외부(DNS)로 대체.
    var primaryLatency: TimeInterval? {
        gatewayRTT ?? dnsRTT
    }

    var isHotspot: Bool = false
    /// OS 레벨(NWPathMonitor) 연결 상태를 공급받아 ping 단발 실패로 인한 거짓 끊김을 걸러낸다.
    weak var hotspotDetector: HotspotDetector?

    private var lastReachable: Bool = true
    private var lastAlertTime: Date?
    private var lastAlertLevel: Int = 0
    private var lastNotifiedLevel: Int = 0
    private var lastConnectionAlertDate: Date = .distantPast
    /// 연속 ping 실패 횟수 (OS가 정상인 동안의 드랍 내성용)
    private var unreachableStrikes = 0

    private var dnsHistory: [TimeInterval?] = []
    private var gatewayHistory: [TimeInterval?] = []
    private let historySize = 20

    /// 연결성 도트 그리드용 최근 핑 성공 기록 (nil=실패, 오래된 순, 게이트웨이 우선·없으면 DNS)
    var recentPingOutcomes: [Bool] {
        zip(gatewayHistory, dnsHistory).map { $0 ?? $1 != nil }
    }

    /// Jitter — 대표 지연(primaryLatency 기준) 최근 기록의 표준편차 (초)
    var jitter: TimeInterval? {
        let samples = gatewayHistory.compactMap { $0 }
        let base = samples.isEmpty ? dnsHistory.compactMap { $0 } : samples
        guard base.count >= 2 else { return nil }
        let mean = base.reduce(0, +) / Double(base.count)
        let variance = base.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(base.count)
        return variance.squareRoot()
    }
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
    private let pingProcessTimeout: TimeInterval = 8.0

    private let notiCenter = UNUserNotificationCenter.current()

    func start() {
        if task != nil {
            task?.cancel()
            task = nil
        }
        gatewayTask?.cancel()
        gatewayTask = Task { [weak self] in
            self?.gatewayAddress = await self?.resolveGateway()
        }
        task = Task { [weak self] in
            await self?.pingLoop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        gatewayTask?.cancel()
        gatewayTask = nil
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
        var useDNS = true
        while !Task.isCancelled {
            let interval = effectiveInterval
            let target = useDNS ? "8.8.8.8" : (gatewayAddress ?? "8.8.8.8")
            let rtt = await performPing(host: target)
            if useDNS {
                dnsRTT = rtt
            } else {
                gatewayRTT = rtt
            }
            applyReachability()
            // 상태 전환 감지는 매 루프에서 수행 (useDNS일 때만 하면 끊김/복구 알림이 누락될 수 있음)
            await checkAndNotify()
            useDNS.toggle()
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    /// ping(probe) 결과 + OS 연결 상태(NWPathMonitor)를 교차 검증해 isReachable을 결정한다.
    /// 단발 드랍(OS 정상)은 끊김으로 보지 않고, 연속 실패가 임계(strikeLimit)에 도달하거나
    /// OS가 unsatisfied일 때만 끊김으로 전환한다.
    private func applyReachability() {
        let pingAlive = (dnsRTT ?? .infinity) < 2.0 || (gatewayRTT ?? .infinity) < 2.0
        let osAvailable = hotspotDetector?.isNetworkAvailable ?? true
        let result = ReachabilityPolicy.evaluate(pingAlive: pingAlive, osAvailable: osAvailable, strikes: unreachableStrikes)
        unreachableStrikes = result.newStrikes
        if isReachable != result.reachable {
            DebugLogger.shared.action("Network", "연결 판정 변화 → \(result.reachable ? "복구" : "끊김") (ping=\(pingAlive) os=\(osAvailable) strikes=\(unreachableStrikes)")
        }
        isReachable = result.reachable
    }

    /// 저전력 모드이면 ping 주기를 최소 15초로 확대해 에너지를 절약한다.
    private var effectiveInterval: TimeInterval {
        let interval = max(SettingsManager.shared.pingInterval, 1.0)
        if SavingModeManager.shared.isLowPowerMode {
            return max(interval, 15.0)
        }
        return interval
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
            let now = Date()
            // 신호 불안정 플래핑 시 알림 폭주를 막기 위한 최소 간격 (30초)
            if now.timeIntervalSince(lastConnectionAlertDate) >= 30 {
                lastConnectionAlertDate = now
                if isReachable {
                    await postPingAlert(type: .connectionRestored, level: 0, message: Localized.connectionRestored)
                } else {
                    await postPingAlert(type: .connectionLost, level: 0, message: Localized.connectionLost)
                }
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
            if let recovery = recoveryStart,
               Date().timeIntervalSince(recovery) >= recoveryDuration {
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
        let dns = dnsRTT
        let gw = gatewayRTT

        if let dns = dns, dns >= criticalThreshold { return 2 }
        if let gw = gw, gw >= gatewayCriticalThreshold { return 2 }
        if let dns = dns, dns >= warningThreshold { return 1 }
        if let gw = gw, gw >= gatewayWarningThreshold { return 1 }
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
        // 레벨 상승(경고→심각)은 cooldown과 무관하게 즉시 알림
        if level > lastNotifiedLevel { return false }
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

    private nonisolated func performPing(host: String) async -> TimeInterval? {
        await withCheckedContinuation { continuation in
            let task = Process()
            // 패킷 3개로 간헐 드랍에 내성을 갖고, 1개 이상 성공하면 응답으로 본다 (v0.31)
            task.launchPath = "/sbin/ping"
            task.arguments = ["-c", "3", "-W", "2000", host]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            let gate = ResumeGate()
            let watchdog = DispatchWorkItem { [weak task] in
                // 정상 종료 후 실행되면 isRunning이 false → terminate 생략
                if task?.isRunning == true {
                    task?.terminate()
                }
                gate.resume {
                    continuation.resume(returning: nil)
                }
            }

            task.terminationHandler = { _ in
                let data = (try? pipe.fileHandleForReading.readDataToEndOfFile()) ?? Data()
                let output = String(data: data, encoding: .utf8) ?? ""
                if task.terminationStatus == 0 {
                    var rtts: [Double] = []
                    for line in output.components(separatedBy: "\n") where line.contains("time=") {
                        guard let msPart = line.components(separatedBy: "time=").last?.components(separatedBy: " ").first,
                              let ms = Double(msPart) else { continue }
                        rtts.append(ms)
                    }
                    if !rtts.isEmpty {
                        let avg = rtts.reduce(0, +) / Double(rtts.count)
                        gate.resume { continuation.resume(returning: avg / 1000.0) }
                        return
                    }
                }
                gate.resume { continuation.resume(returning: nil) }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + pingProcessTimeout, execute: watchdog)

            do {
                try task.run()
            } catch {
                watchdog.cancel()
                gate.resume { continuation.resume(returning: nil) }
            }
        }
    }

    private func postPingAlert(type: AppNotification.NotificationType, level: Int, message: String) async {
        DebugLogger.shared.action("Network", "알림 발송: \(message) (type=\(type.rawValue) level=\(level))")
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

    private nonisolated func resolveGateway() async -> String? {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/usr/sbin/route"
            task.arguments = ["-n", "get", "default"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            let gate = ResumeGate()
            let watchdog = DispatchWorkItem { [weak task] in
                if task?.isRunning == true {
                    task?.terminate()
                }
                gate.resume { continuation.resume(returning: nil) }
            }

            task.terminationHandler = { _ in
                let data = (try? pipe.fileHandleForReading.readDataToEndOfFile()) ?? Data()
                let output = String(data: data, encoding: .utf8) ?? ""
                for line in output.components(separatedBy: "\n") {
                    if line.contains("gateway:") {
                        let gw = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
                        gate.resume { continuation.resume(returning: gw) }
                        return
                    }
                }
                gate.resume { continuation.resume(returning: nil) }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + pingProcessTimeout, execute: watchdog)

            do {
                try task.run()
            } catch {
                watchdog.cancel()
                gate.resume { continuation.resume(returning: nil) }
            }
        }
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isResumed = false

    func resume(_ body: @escaping @Sendable () -> Void) {
        lock.lock()
        guard !isResumed else { lock.unlock(); return }
        isResumed = true
        lock.unlock()
        body()
    }
}
