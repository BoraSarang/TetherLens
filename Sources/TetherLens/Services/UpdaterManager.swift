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
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noPublishedRelease: return Localized.updateNoRelease
        case .fetchFailed: return Localized.updateCheckFailed
        case .rateLimited: return Localized.updateRateLimited
        }
    }
}

/// 릴리스 태그·버전 비교·리다이렉트 URL 파싱 (네트워크 없이 테스트 가능)
enum GitHubReleaseParser {
    /// `/owner/repo/releases/tag/v1.2.3` 최종 URL에서 태그 추출
    static func tag(fromReleaseURL url: URL) -> String? {
        let parts = url.pathComponents
        guard let tagIndex = parts.lastIndex(of: "tag"),
              parts.index(after: tagIndex) < parts.endIndex else { return nil }
        return parts[parts.index(after: tagIndex)]
    }

    /// 태그가 현재 버전보다 새로운지 (`v` 접두 허용, 숫자 비교)
    static func isNewerVersion(_ tag: String, current: String) -> Bool {
        let normalized = tag.replacingOccurrences(of: "^v", with: "", options: .regularExpression)
        return normalized.compare(current, options: .numeric) == .orderedDescending
    }

    /// releases.atom에서 해당 태그 항목의 본문(HTML) 추출 — raw 노트 파일 없을 때 폴백
    static func atomBody(forTag tag: String, in atom: String) -> String? {
        var searchStart = atom.startIndex
        while let entryStart = atom.range(of: "<entry>", range: searchStart..<atom.endIndex) {
            guard let entryEnd = atom.range(of: "</entry>", range: entryStart.upperBound..<atom.endIndex) else { return nil }
            let entry = String(atom[entryStart.lowerBound..<entryEnd.upperBound])
            searchStart = entryEnd.upperBound
            guard entry.contains("/releases/tag/\(tag)") || entry.contains(">\(tag)<") || entry.contains(tag) else { continue }
            guard let contentStart = entry.range(of: "<content"),
                  let openEnd = entry.range(of: ">", range: contentStart.upperBound..<entry.endIndex),
                  let contentEnd = entry.range(of: "</content>") else { continue }
            let raw = String(entry[openEnd.upperBound..<contentEnd.lowerBound])
            return unescapeHTML(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func unescapeHTML(_ s: String) -> String {
        var out = s
        for (entity, ch) in [
            ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")
        ] {
            out = out.replacingOccurrences(of: entity, with: ch)
        }
        return out
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
            if GitHubReleaseParser.isNewerVersion(release.tagName, current: currentVersion) {
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

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var userAgent: String {
        "TetherLens/\(currentVersion)"
    }

    /// 최신 릴리스 조회.
    /// api.github.com 익명 rate limit(60/h/IP) 회피 위해 HTML 리다이렉트 + raw/atom 사용.
    private func fetchLatest() async throws -> GitHubRelease {
        let latestURL = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: latestURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReleaseCheckError.fetchFailed
        }
        if http.statusCode == 404 {
            throw ReleaseCheckError.noPublishedRelease
        }
        if http.statusCode == 403 || http.statusCode == 429 {
            throw ReleaseCheckError.rateLimited
        }
        guard (200...299).contains(http.statusCode),
              let finalURL = response.url,
              let tag = GitHubReleaseParser.tag(fromReleaseURL: finalURL) else {
            throw ReleaseCheckError.fetchFailed
        }
        let notes = await fetchNotes(tag: tag)
        return GitHubRelease(
            tagName: tag,
            htmlURL: finalURL.absoluteString,
            name: tag,
            body: notes
        )
    }

    /// 릴리스 노트: 우선 raw release-notes/{tag}.md(마크다운), 없으면 atom 본문 폴백
    private func fetchNotes(tag: String) async -> String? {
        let rawPath = "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/\(tag)/release-notes/\(tag).md"
        if let url = URL(string: rawPath) {
            var req = URLRequest(url: url)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 15
            if let (data, response) = try? await URLSession.shared.data(for: req),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               let text = String(data: data, encoding: .utf8),
               !text.isEmpty {
                return text
            }
        }
        let atomPath = "https://github.com/\(repoOwner)/\(repoName)/releases.atom"
        if let url = URL(string: atomPath) {
            var req = URLRequest(url: url)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 15
            if let (data, response) = try? await URLSession.shared.data(for: req),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               let atom = String(data: data, encoding: .utf8),
               let body = GitHubReleaseParser.atomBody(forTag: tag, in: atom) {
                return body
            }
        }
        return nil
    }
}