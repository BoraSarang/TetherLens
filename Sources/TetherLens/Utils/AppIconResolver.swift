import AppKit

/// 프로세스명 → 앱 아이콘 (상위 프로세스 행용, 메인 스레드 전용 + 메모리 캐시)
@MainActor
enum AppIconResolver {
    private static var iconCache: [String: NSImage] = [:]
    private static var executableMap: [String: URL]?

    static func icon(forProcess name: String) -> NSImage? {
        if let hit = iconCache[name] { return hit }
        guard let image = resolve(name) else { return nil }
        iconCache[name] = image
        return image
    }

    private static func resolve(_ name: String) -> NSImage? {
        // 1. 실행 중 앱에서 직접 매칭
        if let url = NSWorkspace.shared.runningApplications
            .first(where: { $0.localizedName == name })
            .flatMap({ $0.bundleURL }) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        // 2. 설치된 앱 번들의 실행 파일명으로 매칭 (Helper류 포함)
        if executableMap == nil { executableMap = buildExecutableMap() }
        if let url = executableMap?[name] {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    private static func buildExecutableMap() -> [String: URL] {
        var map: [String: URL] = [:]
        let fm = FileManager.default
        let dirs = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices"
        ]
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let url = URL(fileURLWithPath: dir + "/" + item)
                if let exe = Bundle(url: url)?.executableURL?.lastPathComponent {
                    map[exe] = url
                }
            }
        }
        return map
    }
}
