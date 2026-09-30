import Foundation

final class SavingModeController: @unchecked Sendable {
    static let shared = SavingModeController()

    // 차단 항목은 BEGIN/END 마커로 감싸 한 덩어리로 관리한다.
    // 마커 1줄만 쓰면 sed가 그 1줄만 지워 도메인 줄이 /etc/hosts에 영구 잔존한다.
    private let hostFileBegin = "### TetherLens SavingMode BEGIN ###"
    private let hostFileEnd = "### TetherLens SavingMode END ###"
    private let blockedDomains = [
        "swscan.apple.com",
        "updates.apple.com",
        "mesu.apple.com",
        "su.itunes.apple.com"
    ]

    private init() {}

    /// 기존 차단 블록을 제거하는 sed 명령 (멱등 — 잔여 블록이 있어도 1회 실행이면 정리된다)
    private var removeHostBlockCommand: String {
        "/usr/bin/sed -i '' '/\(hostFileBegin)/,\(hostFileEnd)/d' /etc/hosts"
    }

    func activate(completion: @escaping @Sendable (Bool, String) -> Void) {
        DispatchQueue.global().async {
            let hostEntries = self.blockedDomains.map { "127.0.0.1\t\($0)" }.joined(separator: "\n")
            let script = """
            do shell script "
                /usr/sbin/softwareupdate --schedule off 2>/dev/null
                /usr/bin/tmutil disable 2>/dev/null
                \(self.removeHostBlockCommand)
                /bin/echo '\(self.hostFileBegin)' >> /etc/hosts
                /bin/echo '\(hostEntries)' >> /etc/hosts
                /bin/echo '\(self.hostFileEnd)' >> /etc/hosts
            " with administrator privileges
            """

            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        completion(true, Localized.savingModeActivated)
                    } else {
                        let msg = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(false, msg.isEmpty ? Localized.permissionRequired : msg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    func deactivate(completion: @escaping @Sendable (Bool, String) -> Void) {
        DispatchQueue.global().async {
            let script = """
            do shell script "
                /usr/sbin/softwareupdate --schedule on 2>/dev/null
                /usr/bin/tmutil enable 2>/dev/null
                /usr/bin/sed -i '' '/\(self.hostFileBegin)/,/\(self.hostFileEnd)/d' /etc/hosts
            " with administrator privileges
            """

            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        completion(true, Localized.savingModeDeactivated)
                    } else {
                        let msg = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(false, msg.isEmpty ? Localized.permissionRequired : msg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    func isActive() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/grep"
        task.arguments = ["-q", hostFileBegin, "/etc/hosts"]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
