import Foundation

/// 끊김 시 Wi-Fi 재연결 (v0.35). PingMonitor pingAlert(connectionLost) 구독 — 신규 타이머 없음.
/// 자동 시도는 토글 OFF가 기본, 1회 시도 + 5분 쿨다운 (재연결 루프 방지). 실패는 안내로 끝낸다.
final class ConnectionGuardian: @unchecked Sendable {
    static let shared = ConnectionGuardian()
    static let reconnectCooldown: TimeInterval = 300

    private var lastAttempt: Date?
    private var observer: NSObjectProtocol?

    init() {}

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("pingAlert"), object: nil, queue: nil
        ) { [weak self] note in
            guard let raw = note.userInfo?["type"] as? String,
                  raw == AppNotification.NotificationType.connectionLost.rawValue else { return }
            Task { await self?.handleDisconnect(auto: true) }
        }
    }

    /// 자동 시도 조건 (순수 함수 — 단위 테스트 대상)
    static func shouldAutoReconnect(autoEnabled: Bool, lastAttempt: Date?, now: Date = Date()) -> Bool {
        guard autoEnabled else { return false }
        guard let last = lastAttempt else { return true }
        return now.timeIntervalSince(last) >= reconnectCooldown
    }

    /// `networksetup -listallhardwareports` 출력에서 Wi-Fi 장치명 추출 (순수 함수)
    /// "Hardware Port: Wi-Fi" 다음 "Device: en0"을 찾는다.
    static func parseWifiInterface(_ output: String) -> String? {
        let lines = output.split(separator: "\n").map(String.init)
        for (i, line) in lines.enumerated() {
            guard line.contains("Hardware Port"), line.contains("Wi-Fi") else { continue }
            for j in (i + 1)..<lines.count {
                let t = lines[j].trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("Device:") {
                    return t.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces)
                }
                if t.contains("Hardware Port") { break }
            }
        }
        return nil
    }

    /// 끊김 처리 — 자동이면 조건 확인 후 1회 시도, 수동이면 즉시 시도
    func handleDisconnect(auto: Bool) async {
        if auto {
            guard Self.shouldAutoReconnect(
                autoEnabled: SettingsManager.shared.autoReconnectOnDrop,
                lastAttempt: lastAttempt
            ) else { return }
        }
        lastAttempt = Date()
        let ok = await reconnectNow()
        let message = ok ? Localized.reconnectSuccess : Localized.reconnectFail
        NotificationManager.shared.add(
            type: ok ? .connectionRestored : .connectionLost, message: message)
        await DebugLogger.shared.action("Network", "Wi-Fi 재연결 \(ok ? "성공" : "실패") (\(auto ? "자동" : "수동"))")
    }

    /// Wi-Fi 전원 off/on 사이클. best-effort — sudo 필요 환경이면 실패로 보고한다.
    func reconnectNow() async -> Bool {
        guard let ports = await run("/usr/sbin/networksetup", ["-listallhardwareports"], timeout: 10),
              let device = Self.parseWifiInterface(ports), !device.isEmpty else {
            return false
        }
        guard await run("/usr/sbin/networksetup", ["-setairportpower", device, "off"], timeout: 10) != nil else {
            return false
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        guard await run("/usr/sbin/networksetup", ["-setairportpower", device, "on"], timeout: 10) != nil else {
            return false
        }
        // 전원 상태 재확인으로 성공 판정 (종료 코드만으로는 부족)
        guard let state = await run("/usr/sbin/networksetup", ["-getairportpower", device], timeout: 10),
              state.localizedCaseInsensitiveContains("On") else {
            return false
        }
        return true
    }

    /// 셸 경유 없이 직접 실행 (NetworkDiagnostics.run과 동일 패턴)
    private func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text)
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
