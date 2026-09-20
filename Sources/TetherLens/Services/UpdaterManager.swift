import Foundation
import AppKit
import Combine

// MARK: - 모델

/// GitHub Releases/latest 응답 (마크다운 릴리스 노트 포함)
public struct GitHubRelease: Codable, Sendable, Equatable {
    public let tagName: String
    public let htmlURL: String
    public let name: String?
    public let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
    }
}

/// 업데이트 확인 결과 상태 (설정·팝오버·업데이트 창이 공유)
public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable(tag: String, htmlURL: String, notes: String)
    case unavailable(String)
}

/// 업데이트 확인 주기
public enum UpdateCheckFrequency: String, CaseIterable, Identifiable, Sendable {
    case atLaunch
    case daily
    case weekly
    case never

    public var id: String { rawValue }
}

/// GitHub API 오류 — 404(릴리스 0개)를 전용 에러로 구분 (가이드 실패1 회피)
enum ReleaseCheckError: Error, LocalizedError {
    case noPublishedRelease
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .noPublishedRelease: return Localized.updateNoRelease
        case .fetchFailed: return Localized.updateCheckFailed
        }
    }
}

// MARK: - UpdateManager

@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    private let repoOwner = "BoraSarang"
    private let repoName = "TetherLens"

    @Published private(set) var state: UpdateState = .idle

    private let frequencyKey = "updateCheckFrequency"
    private let checkedAtKey = "updateLastChecked"
    private let launchDate = Date()

    /// 확인 주기 (UserDefaults 영속화, 기본: weekly)
    var frequency: UpdateCheckFrequency {
        get {
            UserDefaults.standard.string(forKey: frequencyKey)
                .flatMap(UpdateCheckFrequency.init(rawValue:)) ?? .weekly
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: frequencyKey) }
    }

    /// 마지막 확인 시각 — UserDefaults에 영속화해야 재실행마다 주기가 초기화되지 않는다 (가이드 실패5)
    private var lastCheckedAt: Date? {
        get { UserDefaults.standard.object(forKey: checkedAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: checkedAtKey) }
    }

    /// 현재 사용 가능한 업데이트 (없으면 nil)
    var availableUpdate: (tag: String, htmlURL: String, notes: String)? {
        if case let .updateAvailable(tag, htmlURL, notes) = state { return (tag, htmlURL, notes) }
        return nil
    }

    var isChecking: Bool {
        if case .checking = state { return true }
        return false
    }

    /// 주기에 따라 필요한 경우에만 조용히 확인한다. 앱 실행·팝오버 열 때 호출.
    func maybeAutoCheckForUpdate() async {
        guard frequency != .never else { return }
        if isChecking { return }
        let now = Date()
        let due: Bool
        switch frequency {
        case .never:
            due = false
        case .atLaunch:
            // "이번 실행에서 아직 확인 안 했으면" — launchDate 이후 확인 여부
            due = lastCheckedAt.map { $0 < launchDate } ?? true
        case .daily:
            due = lastCheckedAt.map { now.timeIntervalSince($0) >= 86_400 } ?? true
        case .weekly:
            due = lastCheckedAt.map { now.timeIntervalSince($0) >= 604_800 } ?? true
        }
        guard due else { return }
        await checkForUpdates()
    }

    /// 즉시 확인 (설정·메뉴 버튼). 상태를 갱신하고 새 버전이면 updateAvailable로 전이.
    func checkForUpdates() async {
        state = .checking
        do {
            let release = try await fetchLatest()
            lastCheckedAt = Date()
            if isNewerVersion(release.tagName) {
                state = .updateAvailable(
                    tag: release.tagName,
                    htmlURL: release.htmlURL,
                    notes: release.body ?? ""
                )
            } else {
                state = .upToDate
            }
        } catch let error as ReleaseCheckError {
            // 404(릴리스 0개)도 "확인은 했음"으로 기록해 매번 재시도하지 않는다
            lastCheckedAt = Date()
            state = .unavailable(error.errorDescription ?? error.localizedDescription)
        } catch {
            state = .unavailable(Localized.updateCheckFailed)
        }
    }

    /// 릴리스 페이지를 기본 브라우저로 연다 (공증 없음 안내 노출 목적 — 지금 버전은 다운로드 버튼과 동일 경로)
    func openDownloadPage() {
        guard let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest") else { return }
        NSWorkspace.shared.open(url)
    }

    /// releases/latest 조회 — 404는 '게시된 릴리스 없음'으로 구분, User-Agent는 번들 버전 사용 (가이드 실패6 회피)
    private func fetchLatest() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        request.setValue("TetherLens/\(version)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReleaseCheckError.fetchFailed
        }
        if http.statusCode == 404 {
            throw ReleaseCheckError.noPublishedRelease
        }
        guard (200...299).contains(http.statusCode) else {
            throw ReleaseCheckError.fetchFailed
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func isNewerVersion(_ tag: String) -> Bool {
        let normalized = tag.replacingOccurrences(of: "^v", with: "", options: .regularExpression)
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return normalized.compare(current, options: .numeric) == .orderedDescending
    }
}