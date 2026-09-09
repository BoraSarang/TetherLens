import SwiftUI

/// StatsEngine 인사이트 카드 행 (v0.34) — 팝오버 시각 언어: hero 숫자 + 컨텍스트 2줄, 장식 테두리 없음.
/// 조용할수록 좋은 지표라 인사이트가 없으면 한 줄 정상 메시지만 표시한다.
struct InsightsView: View {
    let insights: [Insight]
    var onSelectAppTraffic: (() -> Void)? = nil

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.sm) {
            Text(Localized.insightSection)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.textSecondary)
            if insights.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(TLPalette.success).frame(width: 8, height: 8)
                    Text(Localized.insightNone)
                        .font(TLFont.medium)
                        .foregroundColor(TLPalette.textSecondary)
                }
                .padding(.vertical, 2)
            } else {
                VStack(spacing: 6) {
                    ForEach(insights) { insight in
                        insightCard(insight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func insightCard(_ insight: Insight) -> some View {
        let content = HStack(spacing: 10) {
            Image(systemName: icon(for: insight.kind))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color(for: insight.kind))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(hero(for: insight))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(color(for: insight.kind))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(title(for: insight))
                    .font(TLFont.smallBold)
                    .foregroundColor(TLPalette.textPrimary)
                    .lineLimit(1)
                Text(body(for: insight))
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if insight.kind == .topOffender { onSelectAppTraffic?() }
        }
    }

    private func icon(for kind: InsightKind) -> String {
        switch kind {
        case .pace: return "speedometer"
        case .topOffender: return "flame.fill"
        case .anomaly: return "exclamationmark.triangle.fill"
        case .sessionEff: return "bolt.fill"
        }
    }

    private func color(for kind: InsightKind) -> Color {
        switch kind {
        case .pace, .anomaly: return TLPalette.danger
        case .topOffender: return TLPalette.upload
        case .sessionEff: return TLPalette.accent
        }
    }

    private func title(for insight: Insight) -> String {
        switch insight.kind {
        case .pace:
            if let name = insight.profileName, (insight.ratio ?? 0) >= 1.0 {
                return Localized.insightPaceOver(name)
            }
            return Localized.insightPaceTitle
        case .topOffender: return Localized.insightOffenderTitle
        case .anomaly: return Localized.insightAnomalyTitle
        case .sessionEff: return Localized.insightSessionTitle
        }
    }

    private func hero(for insight: Insight) -> String {
        switch insight.kind {
        case .pace:
            if (insight.ratio ?? 0) >= 1.0 { return Localized.statusCritical }
            if let date = insight.date {
                return Self.timeFormatter.string(from: date)
            }
            return "--:--"
        case .topOffender:
            return String(format: "%.0f%%", (insight.ratio ?? 0) * 100)
        case .anomaly:
            return String(format: "%.1f×", insight.ratio ?? 0)
        case .sessionEff:
            return (Int64(insight.ratio ?? 0)).formattedBytes + Localized.perHour
        }
    }

    private func body(for insight: Insight) -> String {
        switch insight.kind {
        case .pace:
            let pct = min(Int((insight.ratio ?? 0) * 100), 999)
            return Localized.insightPaceBody(insight.profileName ?? "", pct)
        case .topOffender:
            return Localized.insightOffenderBody(insight.appName ?? "", (insight.bytes ?? 0).formattedBytes)
        case .anomaly:
            return Localized.insightAnomalyBody((insight.bytes ?? 0).formattedBytes)
        case .sessionEff:
            return Localized.insightSessionBody(insight.profileName ?? "")
        }
    }
}
