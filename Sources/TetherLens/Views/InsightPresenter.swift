import SwiftUI

/// 인사이트 표시 로직 — `InsightSectionView`(리포트)와 `DashboardInsightCard`(대시보드) 공용
///
/// v0.39 이전 대시보드에 인사이트를 넣을 때 그대로 복제하면
/// 종류 추가 시 두 곳을 같이 고쳐야 한다(DRY 위반). 표시 규칙을 한곳에 모았다.
enum InsightPresenter {
    /// 종류별 SF Symbol
    static func icon(for kind: InsightKind) -> String {
        switch kind {
        case .pace: return "speedometer"
        case .topOffender: return "flame.fill"
        case .surge: return "exclamationmark.triangle.fill"
        case .nightDrain: return "moon.fill"
        case .uploadHeavy: return "arrow.up.circle.fill"
        case .ipChurn: return "arrow.triangle.2.circlepath"
        }
    }

    /// 종류별 강조색 (심각도 표현)
    static func color(for kind: InsightKind) -> Color {
        switch kind {
        case .pace, .topOffender: return TLPalette.upload
        case .surge: return TLPalette.danger
        case .nightDrain, .uploadHeavy: return TLPalette.download
        case .ipChurn: return TLPalette.accent
        }
    }

    /// 히어로 값 (카드 좌측 큰 숫자)
    static func hero(for insight: InsightItem) -> String {
        switch insight.kind {
        case .pace:
            if let d = insight.date { return timeFormatter.string(from: d) }
            return "--:--"
        case .topOffender, .nightDrain, .uploadHeavy:
            return "\(Int((insight.ratio ?? 0) * 100))%"
        case .surge:
            return String(format: "%.1f×", insight.ratio ?? 0)
        case .ipChurn:
            return "\(insight.count ?? 0)"
        }
    }

    /// 제목
    static func title(for insight: InsightItem) -> String {
        switch insight.kind {
        case .pace: return Localized.insightPaceTitle(insight.profileName ?? "-")
        case .topOffender: return Localized.insightOffenderTitle(insight.appName ?? "-")
        case .surge: return Localized.insightSurgeTitle
        case .nightDrain: return Localized.insightNightTitle
        case .uploadHeavy: return Localized.insightUploadTitle
        case .ipChurn: return Localized.insightIPTitle
        }
    }

    /// 본문 (1~2줄)
    static func body(for insight: InsightItem) -> String {
        switch insight.kind {
        case .pace:
            let t = insight.date.map { timeFormatter.string(from: $0) } ?? "--:--"
            return Localized.insightPaceBody(t, Int((insight.ratio ?? 0) * 100))
        case .topOffender:
            return Localized.insightOffenderBody((insight.bytes ?? 0).formattedBytes, Int((insight.ratio ?? 0) * 100))
        case .surge:
            return Localized.insightSurgeBody((insight.bytes ?? 0).formattedBytes, String(format: "%.1f", insight.ratio ?? 0))
        case .nightDrain:
            return Localized.insightNightBody(Int((insight.ratio ?? 0) * 100))
        case .uploadHeavy:
            return Localized.insightUploadBody(Int((insight.ratio ?? 0) * 100))
        case .ipChurn:
            return Localized.insightIPBody(insight.count ?? 0)
        }
    }

    /// 카드 클릭을 받을 수 있는 종류 (앱 트래픽 · 진단으로 이동)
    static func isActionable(_ kind: InsightKind) -> Bool {
        kind == .topOffender || kind == .ipChurn
    }

    /// `HH:mm` — 생성 1회당 비용이 있어 static 유지
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
