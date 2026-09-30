import SwiftUI

/// 인사이트 고정 섹션 (v0.36) — 리포트 차트 탭 최상단.
/// 발동 항목이 없으면 녹색 도트 + 한 줄 정상 메시지만 표시한다.
struct InsightSectionView: View {
    let insights: [InsightItem]
    var onShowAppTraffic: (() -> Void)? = nil
    var onOpenDiagnostics: (() -> Void)? = nil

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.sm) {
            Text(Localized.insightSectionTitle)
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
        .padding(.horizontal, TLSpace.xl)
        .padding(.top, TLSpace.sm)
    }

    private func insightCard(_ insight: InsightItem) -> some View {
        HStack(spacing: 10) {
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
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { handleTap(insight) }
        .onHover { inside in
            if tappable(insight.kind) {
                if inside { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
        }
    }

    private func tappable(_ kind: InsightKind) -> Bool {
        kind == .topOffender || kind == .ipChurn
    }

    private func handleTap(_ insight: InsightItem) {
        switch insight.kind {
        case .topOffender: onShowAppTraffic?()
        case .ipChurn: onOpenDiagnostics?()
        default: break
        }
    }

    // MARK: - 표시 규칙은 InsightPresenter 로 이동 (v0.39 — 대시보드 카드와 공용)

    private func icon(for kind: InsightKind) -> String { InsightPresenter.icon(for: kind) }
    private func color(for kind: InsightKind) -> Color { InsightPresenter.color(for: kind) }
    private func hero(for insight: InsightItem) -> String { InsightPresenter.hero(for: insight) }
    private func title(for insight: InsightItem) -> String { InsightPresenter.title(for: insight) }
    private func body(for insight: InsightItem) -> String { InsightPresenter.body(for: insight) }
}
