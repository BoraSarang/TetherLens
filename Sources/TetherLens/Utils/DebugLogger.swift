import Foundation
import Combine

enum DebugLogLevel: String {
    case action = "ACTION"
    case apiReq = "API→"
    case apiRes = "API←"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case system = "SYSTEM"
}

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let level: DebugLogLevel
    let platform: String
    let category: String
    let message: String
    let meta: String?
}

@MainActor
final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    @Published var logs: [DebugLogEntry] = []
    private let maxLogs = 5000
    /// 로그마다 DateFormatter를 새로 만들지 않도록 재사용 (v0.38.1)
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    #if DEBUG
    private let isDebug = true
    #else
    private let isDebug = false
    #endif

    private init() {}

    private func push(_ level: DebugLogLevel, category: String, message: String, meta: Any? = nil) {
        guard isDebug else { return }
        let entry = DebugLogEntry(
            timestamp: Self.timeFormatter.string(from: Date()),
            level: level,
            platform: "MACOS",
            category: category,
            message: message,
            meta: meta != nil ? "\(meta!)" : nil
        )
        // push는 이미 MainActor — 추가 dispatch 불필요 (v0.38.1)
        logs.append(entry)
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        print("[\(entry.timestamp)] [\(level.rawValue)] [\(entry.platform)] [\(category)] \(message)\(entry.meta.map { " | meta=\($0)" } ?? "")")
    }

    func action(_ category: String, _ message: String, meta: Any? = nil) { push(.action, category: category, message: message, meta: meta) }
    func apiCall(_ category: String, _ method: String, _ url: String, body: Any? = nil) { push(.apiReq, category: category, message: "\(method) \(url)", meta: body) }
    func apiResponse(_ category: String, _ status: Int, _ url: String, body: Any? = nil, latency: Int? = nil) { push(.apiRes, category: category, message: "\(status) \(url) latency=\(latency ?? 0)ms", meta: body) }
    func info(_ category: String, _ message: String, meta: Any? = nil) { push(.info, category: category, message: message, meta: meta) }
    func warn(_ category: String, _ message: String, meta: Any? = nil) { push(.warn, category: category, message: message, meta: meta) }
    func error(_ category: String, _ message: String, meta: Any? = nil) { push(.error, category: category, message: message, meta: meta) }
    func system(_ category: String, _ message: String, meta: Any? = nil) { push(.system, category: category, message: message, meta: meta) }

    func clear() { logs.removeAll() }

    func formatForAgent(_ entries: [DebugLogEntry]) -> String {
        entries.map { "[\($0.timestamp)] [\($0.level.rawValue)] [\($0.platform)] [\($0.category)] \($0.message)\($0.meta.map { " | meta=\($0)" } ?? "")" }.joined(separator: "\n")
    }
}
