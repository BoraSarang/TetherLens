import AppKit

/// 메뉴바 앱 단축키 디스패처
///
/// LSUIElement(액세서리) 앱은 시스템 메뉴바가 없어 `NSApp.mainMenu`의 key equivalent가
/// 발화하지 않는다. 즉 `App.swift`의 `.commands` + `keyboardShortcut`는 발화하지 않는다.
/// (기존 디버그 패널 ⌘⇧D만 `MenuBarManager.setupDebugPanelShortcut()`에서 event monitor로 우회했고,
/// 나머지 7개는 죽은 상태였다)
///
/// 여기서는 동일한 event monitor 방식으로 모든 단축키를 처리한다.
/// 미등록 키는 이벤트를 통과시켜 ⌘Q·⌘W 등 시스템 단축키가 막히지 않게 한다.
@MainActor
final class AppShortcuts {
    static let shared = AppShortcuts()

    private var monitor: Any?
    private var handlers: [String: () -> Void] = [:]
    private var didRegisterDefaults = false

    private init() {}

    /// 이벤트를 정규화된 키 문자열로 변환한다. 예: "cmd+shift+f", "cmd+1"
    static func key(for event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // 다른 조합키(control/option/fn)는 시스템/다른 앱 단축키로 남긴다
        guard flags.contains(.command),
              !flags.contains(.control), !flags.contains(.option), !flags.contains(.function)
        else { return nil }

        var parts = ["cmd"]
        if flags.contains(.shift) { parts.append("shift") }
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              chars.count == 1, let scalar = chars.first,
              scalar.isLetter || scalar.isNumber
        else { return nil }
        parts.append(chars)
        return parts.joined(separator: "+")
    }

    /// 동일 키는 마지막 등록이 이긴다 (idempotent)
    func register(_ key: String, _ handler: @escaping () -> Void) {
        handlers[key] = handler
    }

    /// 이미 한 번 등록했으면 다시 하지 않는다 (App.body는 여러 번 평가될 수 있다)
    func registerDefaultsOnce(_ body: () -> Void) {
        guard !didRegisterDefaults else { return }
        didRegisterDefaults = true
        body()
    }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let key = Self.key(for: event) else { return event }
            // addLocalMonitor는 메인 스레드에서 호출된다.
            // 미등록 키는 통과시켜 ⌘Q·⌘W 등 시스템 단축키가 막히지 않게 한다.
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, let handler = self.handlers[key] else { return false }
                handler()
                return true
            }
            return consumed ? nil : event
        }
    }
}
