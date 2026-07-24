import Foundation

struct DNSPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let servers: [String]

    static let google = DNSPreset(name: "Google", servers: ["8.8.8.8", "8.8.4.4"])
    static let cloudflare = DNSPreset(name: "Cloudflare", servers: ["1.1.1.1", "1.0.0.1"])
    static let opendns = DNSPreset(name: "OpenDNS", servers: ["208.67.222.222", "208.67.220.220"])
    static let quad9 = DNSPreset(name: "Quad9", servers: ["9.9.9.9", "149.112.112.112"])
    static let custom = DNSPreset(name: "사용자 설정", servers: [])

    static let presets: [DNSPreset] = [google, cloudflare, opendns, quad9, custom]
}

class DNSManager: @unchecked Sendable {
    static let shared = DNSManager()

    private let serviceName = "Wi-Fi"

    func currentServers() -> [String] {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getdnsservers", serviceName]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if output.contains("There aren't any DNS Servers") {
                return []
            }
            return output.components(separatedBy: .newlines)
                .filter { !$0.isEmpty && !$0.hasPrefix("r") }
                .compactMap { line in
                    guard let ip = line.components(separatedBy: ":").last?
                        .trimmingCharacters(in: .whitespaces),
                        !ip.isEmpty else { return nil }
                    return ip
                }
        } catch {
            return []
        }
    }

    func applyPreset(_ preset: DNSPreset, completion: @escaping (Bool, String) -> Void) {
        let script: String
        if preset.servers.isEmpty {
            script = "do shell script \"/usr/sbin/networksetup -setdnsservers \(serviceName) Empty\" with administrator privileges"
        } else {
            let servers = preset.servers.joined(separator: " ")
            script = "do shell script \"/usr/sbin/networksetup -setdnsservers \(serviceName) \(servers)\" with administrator privileges"
        }

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

            if task.terminationStatus == 0 {
                completion(true, preset.name)
            } else {
                let msg = output.trimmingCharacters(in: .whitespacesAndNewlines)
                completion(false, msg.isEmpty ? "권한이 필요합니다" : msg)
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
}
