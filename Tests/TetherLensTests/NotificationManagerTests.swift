import Testing
import Foundation
@testable import TetherLens

@Suite struct NotificationManagerTests {

    private func makeManager() -> (NotificationManager, String) {
        let suite = "test-noti-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return (NotificationManager(defaults: d), suite)
    }

    /// NotificationManager.add는 main queue mutation — FIFO sync로 flush
    private func flush() {
        DispatchQueue.main.sync {}
    }

    private func teardown(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    @Test func resolveWarnings는_미해소_경고형만_해소한다() {
        let (m, suite) = makeManager()
        m.add(type: .pingWarning, message: "핑 경고")
        m.add(type: .connectionLost, message: "끊김")
        m.add(type: .pingRecovery, message: "복구")
        flush()
        m.resolveWarnings()
        #expect(m.notifications.filter { $0.type == .pingWarning }.allSatisfy { !$0.isActive })
        #expect(m.notifications.filter { $0.type == .connectionLost }.allSatisfy { !$0.isActive })
        #expect(m.notifications.filter { $0.type == .pingRecovery }.allSatisfy { $0.isActive })
        teardown(suite)
    }

    @Test func resolve_type은_해당_타입만_해소한다() {
        let (m, suite) = makeManager()
        m.add(type: .connectionLost, message: "끊김")
        m.add(type: .pingCritical, message: "심각")
        flush()
        m.resolve(type: .connectionLost)
        #expect(m.notifications.filter { $0.type == .connectionLost }.allSatisfy { !$0.isActive })
        #expect(m.notifications.filter { $0.type == .pingCritical }.allSatisfy { $0.isActive })
        teardown(suite)
    }

    @Test func 해소된_알림은_재해소시_시각유지() {
        let (m, suite) = makeManager()
        m.add(type: .pingCritical, message: "심각")
        flush()
        m.resolve(type: .pingCritical)
        let firstResolved = m.notifications[0].resolvedAt
        #expect(firstResolved != nil)
        m.resolveWarnings()
        #expect(m.notifications[0].resolvedAt == firstResolved)
        teardown(suite)
    }

    @Test func 기존저장JSON에_resolvedAt이없으면_nil로디코드된다() throws {
        let json = """
        {"id":"6F1E8C1A-0000-0000-0000-000000000001","timestamp":700000000,
         "type":"pingWarning","message":"경고"}
        """
        let note = try JSONDecoder().decode(AppNotification.self, from: Data(json.utf8))
        #expect(note.resolvedAt == nil)
        #expect(note.isActive)
        #expect(AppNotification.isWarningLike(note.type))
    }

    @Test func 경고성_타입_판별() {
        #expect(AppNotification.isWarningLike(.pingWarning))
        #expect(AppNotification.isWarningLike(.pingCritical))
        #expect(AppNotification.isWarningLike(.connectionLost))
        #expect(!AppNotification.isWarningLike(.pingRecovery))
        #expect(!AppNotification.isWarningLike(.connectionRestored))
        #expect(!AppNotification.isWarningLike(.quotaWarning))
    }
}
