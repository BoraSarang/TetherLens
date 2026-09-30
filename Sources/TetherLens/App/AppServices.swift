import Foundation

/// 앱 전역 서비스 레지스트리
///
/// `MenuBarManager` 가 `HotspotDetector`·`PingMonitor`·`IPResolver` 를 소유하고 있으나,
/// SwiftUI `Window` 씬(대시보드)은 생성 지점에서 주입받을 수 없다.
/// 앱 전역 서비스는 `NetworkMonitor.shared` / `DNSManager.shared` 처럼 싱글턴인 반면
/// 이 셋은 소유자가 하나뿐이라, 여기서 참조만 노출한다(인스턴스 생성 책임은 MenuBarManager).
@MainActor
final class AppServices {
    static let shared = AppServices()

    private(set) var hotspotDetector: HotspotDetector?
    private(set) var pingMonitor: PingMonitor?
    private(set) var ipResolver: IPResolver?

    private init() {}

    /// MenuBarManager 초기화 시 1회 호출
    func register(hotspotDetector: HotspotDetector, pingMonitor: PingMonitor, ipResolver: IPResolver) {
        self.hotspotDetector = hotspotDetector
        self.pingMonitor = pingMonitor
        self.ipResolver = ipResolver
    }
}
