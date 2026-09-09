import Foundation
import Network

// MARK: - 결과 타입

struct DiagnosticsEntry: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let status: DiagnosticsStatus
    let detail: String
}

enum DiagnosticsStatus: Sendable {
    case ok
    case warn
    case fail

    var symbol: String {
        switch self {
        case .ok: "✅"
        case .warn: "⚠️"
        case .fail: "❌"
        }
    }

    var label: String {
        switch self {
        case .ok: "정상"
        case .warn: "주의"
        case .fail: "이상"
        }
    }
}

// MARK: - 진단 엔진

/// 연결 진단 센터의 실행 엔진. 요청 시에만 동작 (상시 폴링 없음).
@MainActor
final class NetworkDiagnostics {
    static let shared = NetworkDiagnostics()

    private init() {}

    // MARK: - Process 헬퍼

    /// 셸 경유 없이 직접 실행. 인자 배열을 그대로 넘겨 쿼트 오염을 방지한다.
    private func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval = 15) async -> String? {
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
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - 항목 진단

    /// scutil --proxy 파싱 — 활성 프록시/시스템 네트워크 설정 요약
    func proxyCheck() async -> DiagnosticsEntry {
        let output = await run("/usr/sbin/scutil", ["--proxy"])
        guard let raw = output, !raw.isEmpty else {
            return DiagnosticsEntry(title: "프록시 / 시스템 설정", status: .fail, detail: "scutil --proxy 실행 불가")
        }

        // <dictionary> { "HTTPEnable" : 1 / "HTTPServer" : "proxy.local:8080" / "SOCKSEnable" : 0 }
        var enables: [String] = []
        var servers: [String] = []
        for rawLine in raw.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.contains("\"") && line.contains(":") else { continue }

            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon])
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            if key.hasSuffix("Enable") {
                let proto = key.replacingOccurrences(of: "Enable", with: "")
                if value.trimmingCharacters(in: .whitespaces) == "1" {
                    enables.append(proto)
                }
            } else if value != "0", !value.isEmpty {
                servers.append("\(key)=\(value)")
            }
        }

        if enables.isEmpty {
            return DiagnosticsEntry(
                title: "프록시 / 시스템 설정",
                status: .ok,
                detail: "시스템 프록시 비활성. VPN은 라우팅/게이트웨이 계층에서 별도 감지됨."
            )
        }
        let detail: String
        if servers.isEmpty {
            detail = "활성 프록시 유형: \(enables.joined(separator: ", "))"
        } else {
            detail = "활성: \(enables.joined(separator: ", ")) | 서버: \(servers.joined(separator: ", "))"
        }
        return DiagnosticsEntry(title: "프록시 / 시스템 설정", status: .warn, detail: detail)
    }

    /// 시스템 DNS resolver와 사용자 설정 DNS(DNSManager) 대조 — 누수 후보 식별
    func dnsLeakCheck() async -> DiagnosticsEntry {
        let dnsOutput = await run("/usr/sbin/scutil", ["--dns"])
        var resolvers: [String] = []
        if let dnsOutput {
            for rawLine in dnsOutput.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("nameserver") || line.hasPrefix("nameserver[") else { continue }
                guard let colon = line.firstIndex(of: ":") else { continue }
                let ip = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if !ip.isEmpty { resolvers.append(ip) }
            }
        }
        resolvers = Array(Set(resolvers)).sorted()

        let userDNS = DNSManager.shared.currentServers().sorted()

        if resolvers.isEmpty {
            return DiagnosticsEntry(
                title: "DNS 누수 검사",
                status: .fail,
                detail: "시스템 DNS resolver를 가져오지 못했습니다 (네트워크 미연결?)"
            )
        }

        let missing = userDNS.filter { !resolvers.contains($0) }
        var note = "시스템 resolver: \(resolvers.joined(separator: ", "))"
        if !userDNS.isEmpty {
            note += "\n사용자 설정 DNS: \(userDNS.joined(separator: ", "))"
        }
        if missing.isEmpty {
            note += "\n→ 사용자 DNS가 시스템 resolver에 반영, 누수 후보 없음"
            return DiagnosticsEntry(title: "DNS 누수 검사", status: .ok, detail: note)
        } else {
            note += "\n→ 누수 후보: \(missing.joined(separator: ", ")) (분리 DNS/터널 경유?)"
            return DiagnosticsEntry(title: "DNS 누수 검사", status: .warn, detail: note)
        }
    }

    /// 사용자 지정 호스트에 대해 ping 실행 (커스텀 핑)
    func customPing(host: String) async -> DiagnosticsEntry {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateHostName(trimmed) else {
            return DiagnosticsEntry(title: "핑 (커스텀)", status: .fail, detail: "호스트 형식 오류: \(host). 도메인/IP만 허용.")
        }
        let output = await run("/sbin/ping", ["-c", "5", "-t", "10", trimmed], timeout: 14)
        guard let raw = output else {
            return DiagnosticsEntry(title: "핑 (커스텀)", status: .fail, detail: "실행 실패/타임아웃: \(trimmed)")
        }
        let summary = raw.split(separator: "\n")
            .first { $0.contains("packet loss") }?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let rtt = raw.split(separator: "\n")
            .first { $0.contains("round-trip") }?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let ok = summary.contains("0% packet loss") || summary.contains("0.0% packet loss")
        return DiagnosticsEntry(
            title: "핑 (커스텀)",
            status: ok ? .ok : .warn,
            detail: "\(trimmed)\n\(summary)\(rtt.isEmpty ? "" : "\n\(rtt)")"
        )
    }

    /// traceroute — 12홉 내 경로 표시
    func traceroute(host: String) async -> DiagnosticsEntry {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateHostName(trimmed) else {
            return DiagnosticsEntry(title: "트레이스", status: .fail, detail: "호스트 형식 오류: \(host)")
        }
        let output = await run("/usr/sbin/traceroute", ["-m", "12", "-q", "1", "-w", "2", trimmed], timeout: 30)
        guard let raw = output, !raw.isEmpty else {
            return DiagnosticsEntry(title: "트레이스", status: .fail, detail: "경로 확보 실패/타임아웃: \(trimmed)")
        }
        let lines = raw.split(separator: "\n").map(String.init)
        let head = lines.first ?? ""
        let hops = lines.dropFirst().prefix(12).joined(separator: "\n")
        return DiagnosticsEntry(
            title: "트레이스 (\(trimmed))",
            status: hops.isEmpty ? .fail : .ok,
            detail: "\(head)\n\(hops)"
        )
    }

    // MARK: - bufferbloat

    /// 다운로드 부하 중 RTT 증가 폭으로 bufferbloat를 추정한다.
    func bufferbloat() async -> DiagnosticsEntry {
        let idles = await sampleRTT(underLoad: false)
        let loads = await sampleRTT(underLoad: true)

        guard let idleAvg = average(idles), let loadAvg = average(loads) else {
            return DiagnosticsEntry(title: "bufferbloat 추정", status: .fail, detail: "핑 측정 실패 — 네트워크 상태 확인 필요")
        }
        let delta = loadAvg - idleAvg
        let status: DiagnosticsStatus = delta <= 5 ? .ok : (delta <= 30 ? .warn : .fail)
        let verdict: String
        if delta <= 5 { verdict = "양호" }
        else if delta <= 30 { verdict = "완충 발현 (실시간 앱 지연 폭)" }
        else { verdict = "완충 위험" }
        return DiagnosticsEntry(
            title: "bufferbloat 추정",
            status: status,
            detail: String(format: "idle 평균 %.0fms → 아래드 평균 %.0fms (+%.0fms) | 판정: %@", idleAvg, loadAvg, delta, verdict)
        )
    }

    private func sampleRTT(underLoad: Bool) async -> [Double] {
        var samples: [Double] = []
        let loadTask = underLoad ? Task.detached(priority: .utility) { await Self.downloadLoad() } : nil
        defer { loadTask?.cancel() }

        for _ in 0..<3 {
            let out = await run("/sbin/ping", ["-c", "1", "-W", "2000", "-t", "3", "8.8.8.8"], timeout: 5)
            if let out, let rtt = parseRTT(out) {
                samples.append(rtt)
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return samples
    }

    private func parseRTT(_ output: String) -> Double? {
        for line in output.split(separator: "\n") {
            guard let range = line.range(of: "time=") else { continue }
            let num = line[range.upperBound...].prefix { $0.isNumber || $0 == "." }
            return Double(num)
        }
        return nil
    }

    private static func downloadLoad() async {
        guard let url = URL(string: "https://speed.hetzner.de/1MB.bin") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10
        do {
            let (data, _) = try await URLSession(configuration: .ephemeral).data(for: request)
            if data.isEmpty {}
        } catch {}
    }

    // MARK: - speed test (v0.35)

    /// 속도 테스트 상수. 다운은 Cloudflare 1차 + hetzner 폴백 (hetzner 단독 실패 실측).
    nonisolated static let speedTestDownURLs = [
        URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!,
        URL(string: "https://speed.hetzner.de/10MB.bin")!,
    ]
    nonisolated static let speedTestUpURL = URL(string: "https://speed.cloudflare.com/__up")!
    nonisolated static let speedTestDownBytes: Int64 = 10_000_000
    nonisolated static let speedTestUpBytes: Int64 = 5_000_000
    nonisolated static let speedTestTimeout: TimeInterval = 30

    /// 바이트·전송시간 → Mbps. 핸드셰이크 제외는 호출자가 firstByte 기준으로 계산한다.
    nonisolated static func megabitsPerSecond(bytes: Int64, elapsed: TimeInterval) -> Double? {
        guard bytes > 0, elapsed > 0 else { return nil }
        return Double(bytes) * 8 / elapsed / 1_000_000
    }

    /// 현재 경로가 유료/제한망인지 원샷 확인 (핫스팟 경고용, 상시 모니터 없음)
    func isCurrentPathExpensive() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.isExpensive)
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
        }
    }

    /// 다운/업 실측. 수동 개시 전용 — 상시 측정 없음 (데이터·에너지 정책).
    func speedTest() async -> DiagnosticsEntry {
        async let down = measureDownload()
        async let up = measureUpload()
        let (downMbps, upMbps) = await (down, up)
        guard let downMbps else {
            return DiagnosticsEntry(title: "속도 테스트", status: .fail, detail: "다운로드 측정 실패/타임아웃 — 네트워크 상태 확인 필요")
        }
        var detail = String(format: "다운 %.1f Mbps", downMbps)
        var status = DiagnosticsStatus.ok
        if let upMbps {
            detail += String(format: " · 업 %.1f Mbps", upMbps)
        } else {
            detail += " · 업 측정 실패"
            status = .warn
        }
        detail += String(format: " (측정 소모 약 %.0fMB)", Double(Self.speedTestDownBytes + Self.speedTestUpBytes) / 1_000_000)
        detail += "\n→ 저하 시 공유기 근접 후 재측정 — 그래도 낮으면 ISP 문제 가능"
        return DiagnosticsEntry(title: "속도 테스트", status: status, detail: detail)
    }

    private func measureDownload() async -> Double? {
        for url in Self.speedTestDownURLs {
            if let mbps = await measureDownload(from: url) { return mbps }
        }
        return nil
    }

    private func measureDownload(from url: URL) async -> Double? {
        await withSpeedTimeout(seconds: Self.speedTestTimeout) {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                let session = URLSession(configuration: .ephemeral)
                let (bytes, _) = try await session.bytes(for: request)
                var total: Int64 = 0
                var firstByte: Date?
                for try await _ in bytes {
                    if firstByte == nil { firstByte = Date() }
                    total += 1
                }
                guard total > 0, let first = firstByte else { return nil }
                return Self.megabitsPerSecond(bytes: total, elapsed: Date().timeIntervalSince(first))
            } catch {
                return nil
            }
        }
    }

    private func measureUpload() async -> Double? {
        await withSpeedTimeout(seconds: Self.speedTestTimeout) {
            do {
                var request = URLRequest(url: Self.speedTestUpURL)
                request.httpMethod = "POST"
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                let payload = Data(repeating: 0xAB, count: Int(Self.speedTestUpBytes))
                let session = URLSession(configuration: .ephemeral)
                let start = Date()
                let (_, response) = try await session.upload(for: request, from: payload)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                return Self.megabitsPerSecond(bytes: Int64(payload.count), elapsed: Date().timeIntervalSince(start))
            } catch {
                return nil
            }
        }
    }

    /// 타임아웃 래퍼 — 먼저 끝난 쪽(성공/실패/시간초과)을 결과로 확정한다.
    private func withSpeedTimeout<T: Sendable>(seconds: TimeInterval, operation: @Sendable @escaping () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self, returning: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            var result: T?
            var settled = false
            for await value in group {
                if !settled {
                    result = value
                    settled = true
                    group.cancelAll()
                }
            }
            return result
        }
    }

    // MARK: - 리포트

    /// 진단 결과 모음을 markdown 리포트 문자열로 만든다.
    func renderMarkdown(_ entries: [DiagnosticsEntry]) -> String {
        var lines: [String] = []
        lines.append(contentsOf: [
            "# TetherLens 네트워크 진단 리포트",
            "",
            "- 생성: \(Date.now.formatted(date: .numeric, time: .standard))",
            ""
        ])
        for e in entries {
            lines.append("## \(e.status.symbol) \(e.title) — \(e.status.label)")
            lines.append("")
            for chunk in e.detail.split(whereSeparator: { $0 == "\n" }) {
                lines.append("- \(chunk)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

private func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

private func validateHostName(_ host: String) -> Bool {
    let pattern = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(location: 0, length: host.utf16.count)
    return regex.firstMatch(in: host, range: range) != nil
}