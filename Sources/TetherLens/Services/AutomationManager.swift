import AppKit
import Foundation

/// SSID 전환 기반 자동화 규칙.
/// 예) "내 iPhone" 핫스팟 연결 → 특정 앱 실행 / 절약 모드 켜기
struct AutomationRule: Codable, Identifiable, Equatable {
    enum TriggerType: String, Codable, CaseIterable, Identifiable {
        case onConnect
        case onDisconnect
        var id: String { rawValue }
        var label: String {
            switch self {
            case .onConnect: "연결 시"
            case .onDisconnect: "해제 시"
            }
        }
    }

    enum ActionType: String, Codable, CaseIterable, Identifiable {
        case launchApp
        case quitProcess
        case savingModeOn
        case savingModeOff
        var id: String { rawValue }
        var label: String {
            switch self {
            case .launchApp: "앱 실행"
            case .quitProcess: "프로세스 종료"
            case .savingModeOn: "절약 모드 켜기"
            case .savingModeOff: "절약 모드 끄기"
            }
        }
    }

    var id = UUID()
    var name: String
    var ssid: String
    var trigger: TriggerType
    var action: ActionType
    var target: String  // 앱 이름/프로세스명. saving 모드는 비워 둠
    var isEnabled = true

    var summary: String {
        "\(name) — \(ssid) \(trigger.label) ▶ \(action.label)\(target.isEmpty ? "" : " (\(target))")"
    }
}

/// 자동화 규칙 저장(UserDefaults JSON) 및 SSID 전환 평가.
@MainActor
final class AutomationManager {
    static let shared = AutomationManager()

    private let storeKey = "automation_rules_v1"
    private let cooldownKey = "automation_cooldown_v1"
    private let cooldownDuration: TimeInterval = 60

    private(set) var rules: [AutomationRule] = []

    private init() {
        loadRules()
    }

    // MARK: - 저장

    private func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return }
        rules = (try? JSONDecoder().decode([AutomationRule].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    func save(_ rule: AutomationRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
        } else {
            rules.append(rule)
        }
        persist()
    }

    func delete(_ rule: AutomationRule) {
        rules.removeAll { $0.id == rule.id }
        persist()
    }

    // MARK: - 평가

    /// SSID 전환 시 호출. 매칭 규칙을 실행한다. 동일 규칙에 60초 쿨다운 적용.
    func evaluate(ssid: String?, connected: Bool) {
        guard let ssid, !ssid.isEmpty else { return }
        for rule in rules where rule.isEnabled && rule.ssid == ssid {
            let shouldFire = connected ? rule.trigger == .onConnect : rule.trigger == .onDisconnect
            guard shouldFire else { continue }
            guard !isCoolingDown(rule) else { continue }
            markCooldown(rule)
            DebugLogger.shared.action("Automation", "규칙 실행: \(rule.summary)")
            execute(rule)
        }
    }

    private func execute(_ rule: AutomationRule) {
        switch rule.action {
        case .launchApp:
            guard !rule.target.isEmpty else { return }
            AutomationRunner.launchApp(named: rule.target) { ok, detail in
                if !ok { DebugLogger.shared.error("Automation", "앱 실행 실패: \(detail)") }
            }
        case .quitProcess:
            guard !rule.target.isEmpty else { return }
            AutomationRunner.quitProcess(named: rule.target)
        case .savingModeOn:
            SavingModeController.shared.activate { ok, msg in
                if ok {
                    NotificationCenter.default.post(name: .init("savingModeChanged"), object: nil)
                }
            }
        case .savingModeOff:
            SavingModeController.shared.deactivate { ok, msg in
                if ok {
                    NotificationCenter.default.post(name: .init("savingModeChanged"), object: nil)
                }
            }
        }
    }

    // MARK: - 쿨다운

    private func cooldownKey(for rule: AutomationRule) -> String {
        "\(Int(cooldownDuration))|\(rule.id.uuidString)"
    }

    private func isCoolingDown(_ rule: AutomationRule) -> Bool {
        guard let ts = UserDefaults.standard.object(forKey: cooldownKey(for: rule)) as? TimeInterval else {
            return false
        }
        return Date().timeIntervalSince1970 - ts < cooldownDuration
    }

    private func markCooldown(_ rule: AutomationRule) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cooldownKey(for: rule))
    }
}

/// 앱 실행/프로세스 종료를 수행하는 유틸. (셸 경유 금지 — 인자 배열 사용)
@MainActor
enum AutomationRunner {
    static func launchApp(named name: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = likelyAppURL(named: name) else {
            completion(false, "앱을 찾지 못했습니다: \(name)")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
            if let error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, "")
            }
        }
    }

    static func quitProcess(named name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["-q", name]
        try? process.run()
        DebugLogger.shared.action("Automation", "프로세스 종료 요청: \(name)")
    }

    private static func likelyAppURL(named name: String) -> URL? {
        if let url = appURL(named: name) { return url }
        if name.lowercased().hasSuffix(".app") { return appURL(named: String(name.dropLast(4))) ?? appURL(named: name) }
        return URL(fileURLWithPath: name)
    }

    private static func appURL(named name: String) -> URL? {
        let dirs = [
            "/Applications",
            "/Applications/Utilities",
            NSString(string: "~/Applications").expandingTildeInPath
        ]
        for dir in dirs {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).app")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
}