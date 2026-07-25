import Foundation

final class SavingModeController: @unchecked Sendable {
    static let shared = SavingModeController()

    private let hostFileMarker = "# TetherLens SavingMode"
    private let blockedDomains = [
        "swscan.apple.com",
        "updates.apple.com",
        "mesu.apple.com",
        "su.itunes.apple.com"
    ]

    private init() {}

    func activate(completion: @escaping @Sendable (Bool, String) -> Void) {
        DispatchQueue.global().async {
            let hostEntries = self.blockedDomains.map { "127.0.0.1\t\($0)" }.joined(separator: "\\n")
            let script = """
            do shell script "
                /usr/sbin/softwareupdate --schedule off 2>/dev/null
                /usr/bin/tmutil disable 2>/dev/null
                /bin/echo '\(self.hostFileMarker)' >> /etc/hosts
                /bin/echo '\(hostEntries)' >> /etc/hosts
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
                        completion(true, "절약 모드가 적용되었습니다")
                    } else {
                        let msg = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(false, msg.isEmpty ? "권한이 필요합니다" : msg)
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
                /usr/bin/sed -i '' '/\(self.hostFileMarker)/,/\(self.hostFileMarker)/d' /etc/hosts
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
                        completion(true, "절약 모드가 해제되었습니다")
                    } else {
                        let msg = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(false, msg.isEmpty ? "권한이 필요합니다" : msg)
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
        task.arguments = ["-q", hostFileMarker, "/etc/hosts"]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
