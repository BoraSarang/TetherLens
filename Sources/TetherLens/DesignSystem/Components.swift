import SwiftUI

// MARK: - TetherLens 공용 마이크로 컴포넌트 (v0.37)
// iStat Menus 카드 + RelayConsole shell/스파크라인 패턴

/// 합계 대비 점유율 (0...1). total 비이상이면 0.
enum TLShare {
    static func ratio(_ value: Double, of total: Double) -> Double {
        guard total.isFinite, total > 0, value.isFinite else { return 0 }
        return min(max(value / total, 0), 1)
    }
}

/// 링 히스토리 미니 라인 — min-max 정규화 Path 스파크라인.
struct TLSparkline: View {
    let points: [Double]
    var color: Color = TLPalette.download
    var height: CGFloat = 24
    var lineWidth: CGFloat = 1.25

    var body: some View {
        Group {
            if points.count >= 2 {
                GeometryReader { geo in
                    let minV = points.min() ?? 0
                    let maxV = points.max() ?? 1
                    ZStack {
                        Rectangle()
                            .fill(color.opacity(0.2))
                            .frame(height: 1)
                        Path { path in
                            let rawRange = maxV - minV
                            let flat = rawRange < 0.0001
                            for (i, v) in points.enumerated() {
                                let x = geo.size.width * CGFloat(i) / CGFloat(points.count - 1)
                                let y: CGFloat = flat
                                    ? geo.size.height * 0.5
                                    : geo.size.height * (1 - CGFloat((v - minV) / rawRange))
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(color, lineWidth: lineWidth)
                    }
                }
                .frame(height: height)
                .clipped()
            } else {
                Rectangle()
                    .fill(color.opacity(0.25))
                    .frame(height: 2)
                    .frame(height: height)
            }
        }
    }
}

/// 행 하단 점유율 가로 바 (iStat Menus Top Talkers) — 높이 2pt 고정.
struct TLShareBar: View {
    let ratio: Double
    var color: Color = TLPalette.download

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(color.opacity(0.15))
                Rectangle()
                    .fill(color)
                    .frame(width: w * CGFloat(min(max(ratio, 0), 1)))
            }
        }
        .frame(height: 2)
    }
}

/// 지표 카드 셸 — RelayConsole DroidCards.shell 패턴.
/// title 오른쪽 trailing(수치)을 우측 정렬로 함께 표시할 수 있다.
/// backgroundOpacity: 플로팅 투명도 연동용 (카드 배경·테두리만 흐려짐, 텍스트는 선명 유지).
struct MetricCard<Content: View>: View {
    let title: String
    var compact = false
    var trailing: String? = nil
    var trailingFont: Font? = nil
    var backgroundOpacity: Double = 1
    @ViewBuilder let content: Content

    private var radius: CGFloat { compact ? 8 : TLRound.medium }
    private var bgAlpha: Double { min(max(backgroundOpacity, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack(alignment: .firstTextBaseline, spacing: TLSpace.sm) {
                Text(title)
                    .font(TLFont.smallBold)
                    .foregroundColor(TLPalette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let trailing {
                    Text(trailing)
                        .font(trailingFont ?? TLFont.mediumMono)
                        .foregroundColor(TLPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(compact
                 ? EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
                 : EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        .background(
            TLPalette.cardBackground.opacity(bgAlpha),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(TLPalette.separator.opacity(0.5 * bgAlpha), lineWidth: 1)
        )
    }
}

/// 게이지 바 — ProgressView linear (RelayConsole 카드 동일).
struct TLGaugeBar: View {
    /// 0...100
    let value: Double
    var tint: Color = TLPalette.download

    var body: some View {
        ProgressView(value: min(max(value, 0), 100), total: 100)
            .progressViewStyle(.linear)
            .tint(tint)
            .frame(height: 4)
    }
}

/// 코어별 사용률 막대 (iStat C0…Cn).
struct TLCoreBars: View {
    let percents: [Double]
    var tint: Color = TLPalette.download

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(percents.enumerated()), id: \.offset) { idx, pct in
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        let ratio = CGFloat(min(max(pct, 0), 100) / 100)
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tint.opacity(0.25))
                                .frame(height: geo.size.height)
                                .overlay(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(tint.opacity(0.85))
                                        .frame(height: max(3, geo.size.height * ratio))
                                }
                        }
                    }
                    .frame(height: 28)
                    Text("C\(idx)")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(TLPalette.textSecondary)
                }
            }
        }
    }
}

// MARK: - 시스템 지표 카드 (iStat Menus 스타일)

/// CPU / GPU / MEMORY 카드 — 표시 깊이 detail로 분기.
struct SystemMetricsCards: View {
    enum Detail {
        /// 플로팅: 큰 수치 + 게이지 + 스파크라인
        case compact
        /// 팝오버: + load + 프로세스 Top3
        case standard
        /// 앱 트래픽: + 코어 막대 + 프로세스 Top5 + 더보기
        case full
    }

    @ObservedObject private var history = MetricsHistory.shared
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @AppStorage("showCPUGraph") private var showCPUGraph = false
    @AppStorage("showGPUGraph") private var showGPUGraph = false
    @AppStorage("showMemGraph") private var showMemGraph = true

    var detail: Detail = .standard
    var cpuTop: [(name: String, res: ProcessResource)] = []
    var memTop: [(name: String, res: ProcessResource)] = []
    var onShowProcesses: (() -> Void)? = nil
    /// 플로팅 투명도 — 카드 배경에만 적용 (기본 1 = 불투명)
    var backgroundOpacity: Double = 1
    /// true면 showCPUGraph/showGPUGraph/showMemGraph 토글 무시하고 3카드 항상 표시
    /// (앱 트래픽 창 — 플로팅/설정 토글과 무관)
    var alwaysShowAll: Bool = false

    private var anyVisible: Bool {
        alwaysShowAll || showCPUGraph || (showGPUGraph && gpuAvailable) || showMemGraph
    }

    var body: some View {
        if anyVisible {
            VStack(spacing: TLSpace.md) {
                if alwaysShowAll || showCPUGraph {
                    cpuCard
                }
                if (alwaysShowAll && gpuAvailable) || (showGPUGraph && gpuAvailable) {
                    gpuCard
                }
                if alwaysShowAll || showMemGraph {
                    memoryCard
                }
            }
        }
    }

    private var gpuAvailable: Bool {
        trafficMonitor.systemLoad?.gpuPercent != nil || !history.gpuHistory.isEmpty
    }

    private var accent: Color { TLPalette.download }

    // MARK: CPU

    private var cpuCard: some View {
        let cpu = trafficMonitor.systemLoad?.cpuTotalPercent
        let load = trafficMonitor.systemLoad?.load1
        return MetricCard(
            title: Localized.cpu,
            compact: detail == .compact,
            trailing: SystemResourceMonitor.formatCPU(cpu),
            trailingFont: cpuHeroFont,
            backgroundOpacity: backgroundOpacity
        ) {
            if detail != .compact, let load {
                Text(String(format: "load %.2f", load))
                    .font(TLFont.mediumMono)
                    .foregroundColor(TLPalette.textSecondary)
            }
            if let cpu {
                TLGaugeBar(value: cpu, tint: TLPalette.cpuHeat(cpu))
            }
            if detail == .full {
                let cores = trafficMonitor.systemLoad?.perCore ?? []
                if !cores.isEmpty {
                    TLCoreBars(percents: cores, tint: accent)
                }
            }
            TLSparkline(points: history.cpuHistory, color: accent, height: detail == .compact ? 16 : 24)
            if !cpuTop.isEmpty {
                VStack(spacing: 2) {
                    ForEach(cpuTop, id: \.name) { entry in
                        HStack(spacing: TLSpace.sm) {
                            Text(entry.name)
                                .font(TLFont.medium)
                                .foregroundColor(TLPalette.textPrimary.opacity(0.85))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Text(SystemResourceMonitor.formatCPU(entry.res.cpuPercent))
                                .font(TLFont.mediumMono)
                                .foregroundColor(TLPalette.cpuHeat(entry.res.cpuPercent))
                        }
                    }
                }
            }
        }
    }

    // MARK: GPU

    private var gpuCard: some View {
        let gpu = trafficMonitor.systemLoad?.gpuPercent
        return MetricCard(
            title: Localized.gpu,
            compact: detail == .compact,
            trailing: SystemResourceMonitor.formatCPU(gpu),
            trailingFont: cpuHeroFont,
            backgroundOpacity: backgroundOpacity
        ) {
            if let gpu {
                TLGaugeBar(value: gpu, tint: accent)
            }
            TLSparkline(points: history.gpuHistory, color: accent, height: detail == .compact ? 16 : 24)
        }
    }

    // MARK: Memory

    private var memoryCard: some View {
        let used = trafficMonitor.systemLoad?.memUsedBytes ?? -1
        let total = trafficMonitor.systemLoad?.memTotalBytes ?? -1
        let ratio: Double = (used >= 0 && total > 0) ? Double(used) / Double(total) * 100 : 0
        return MetricCard(
            title: Localized.memory,
            compact: detail == .compact,
            trailing: SystemResourceMonitor.formatMemUsedTotal(used: used, total: total),
            trailingFont: cpuHeroFont,
            backgroundOpacity: backgroundOpacity
        ) {
            if used >= 0, total > 0 {
                TLGaugeBar(value: ratio, tint: memTint(ratio: ratio))
            }
            TLSparkline(points: history.memHistory, color: accent, height: detail == .compact ? 16 : 24)
            if !memTop.isEmpty {
                VStack(spacing: 2) {
                    ForEach(memTop, id: \.name) { entry in
                        HStack(spacing: TLSpace.sm) {
                            Text(entry.name)
                                .font(TLFont.medium)
                                .foregroundColor(TLPalette.textPrimary.opacity(0.85))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            if total > 0 {
                                Text(String(format: "%.1f%%", Double(entry.res.rssBytes) / Double(total) * 100))
                                    .font(TLFont.mediumMono)
                                    .foregroundColor(accent)
                            }
                            Text(SystemResourceMonitor.formatMemory(entry.res.rssBytes))
                                .font(TLFont.mediumMono)
                                .foregroundColor(TLPalette.textSecondary)
                        }
                    }
                }
                if detail == .full, let onShowProcesses {
                    Button(action: onShowProcesses) {
                        Text(Localized.processListMore)
                            .font(TLFont.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(accent)
                }
            }
        }
    }

    private var cpuHeroFont: Font {
        .system(size: detail == .compact ? 14 : 18, weight: .semibold, design: .monospaced)
    }

    private func memTint(ratio: Double) -> Color {
        if ratio >= 85 { return TLPalette.danger }
        if ratio >= 70 { return TLPalette.upload }
        return accent
    }
}
