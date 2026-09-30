import Foundation

/// 대시보드 카드 식별 — **순서·행 구성의 단일 진실원처**
///
/// RelayConsole `Views/DashboardLayout.swift` 와 동일 구조.
/// 이 파일 하나만 수정하면 대시보드 레이아웃 순서가 바뀐다(뷰 코드 수정 불필요).
enum DashboardCard: String, CaseIterable, Identifiable, Sendable {
    // 네트워크 관제
    case speed
    case quality
    // 데이터 통제
    case quota
    case pattern
    // 머신 자원
    case cpu
    case gpu
    case memory
    case process
    /// 인사이트 — 목록형이라 전폭으로 뺀다 (RelayConsole `wideCards` 규칙)
    case insight

    var id: String { rawValue }

    /// 2열 행 구성 — 정보 계층 선언
    ///
    /// **네트워크(지금 이쪽이 문제다) → 데이터 통제(얼마나 썼나) → 머신 자원(CPU/GPU/RAM) → 프로세스**
    /// 행 안 카드는 `MetricCard(fillsRow:)` 로 배경이 행 바닥까지 늘어나므로
    /// 높이가 달라도 시각적으로 어긋나지 않는다 (RelayConsole `DroidCards.shell(fillsRow:)`).
    static let rows: [[DashboardCard]] = [
        [.speed, .quality],   // 1행 — 실시간 관제
        [.quota, .pattern],   // 2행 — 데이터 통제
        [.cpu, .gpu],         // 3행 — CPU / GPU
        [.memory, .process]    // 4행 — RAM / 프로세스 리스트
    ]

    /// 전폭 단독 카드 — 목록형이라 그리드 아래 한 줄
    static let wideCards: [DashboardCard] = [.insight]

    /// 표시 순서 (행 펼침 → wide) — 설정 카드 토글 미러링용
    static var ordered: [DashboardCard] { rows.flatMap { $0 } + wideCards }

    /// 카드 제목
    var title: String {
        switch self {
        case .speed:   return Localized.string("실시간 속도", "Live Speed")
        case .quality: return Localized.string("연결 품질", "Connection Quality")
        case .quota:   return Localized.string("할당량 · 예측", "Quota & Forecast")
        case .pattern: return Localized.string("오늘 사용 패턴", "Today's Pattern")
        case .cpu:     return Localized.cpu
        case .gpu:     return Localized.gpu
        case .memory:  return Localized.memory
        case .process: return Localized.string("프로세스", "Processes")
        case .insight: return Localized.insightSectionTitle
        }
    }

    /// SF Symbol
    var symbol: String {
        switch self {
        case .speed:   return "arrow.up.arrow.down"
        case .quality: return "waveform.path.ecg"
        case .quota:   return "gauge.with.dots.needle.67percent"
        case .pattern: return "chart.bar.xaxis"
        case .cpu:     return "cpu"
        case .gpu:     return "displaytriangle"
        case .memory:  return "memorychip"
        case .process: return "list.bullet.rectangle"
        case .insight: return "sparkle.magnifyingglass"
        }
    }
}
