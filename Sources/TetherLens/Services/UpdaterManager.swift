import Foundation
import AppKit

@MainActor
final class UpdaterManager {
    static let shared = UpdaterManager()

    private let currentVersion: String
    private let repoOwner = "BoraSarang"
    private let repoName = "TetherLens"

    struct UpdateInfo {
        let version: String
        let downloadURL: String
        let releaseNotes: String
    }

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() async -> UpdateInfo? {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let tagName = (json?["tag_name"] as? String)?
                .replacingOccurrences(of: "^v", with: "", options: .regularExpression) ?? ""
            if isNewerVersion(tagName) {
                let downloadURL = (json?["html_url"] as? String) ??
                    "https://github.com/\(repoOwner)/\(repoName)/releases/latest"
                let releaseNotes = json?["body"] as? String ?? ""
                return UpdateInfo(version: tagName, downloadURL: downloadURL, releaseNotes: releaseNotes)
            }
            return nil
        } catch {
            DebugLogger.shared.warn("Updater", "업데이트 확인 실패: \(error.localizedDescription)")
            return nil
        }
    }

    func openDownloadPage() {
        let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")!
        NSWorkspace.shared.open(url)
    }

    private func isNewerVersion(_ latest: String) -> Bool {
        return latest.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}
