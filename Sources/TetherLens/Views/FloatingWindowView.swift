import SwiftUI
import Charts

/// 플로팅 창 본체 — 네트워크 카드(팝오버 동일 차트+프로세스 Top3) + 켜진 시스템 카드.
/// borderless NSPanel(NonActivating) 안에서 호스팅된다 (FloatingWindowController 소유).
/// 네트워크는 항상 표시, 프로세스/그래프 분리 토글 없음 (v0.37.1).
struct FloatingWindowView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: FloatingWindowViewModel
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @AppStorage("appTraffic_show_system") private var showSystem = false
    @AppStorage("showCPUGraph") private var showCPUGraph = false
    @AppStorage("showGPUGraph") private var showGPUGraph = false
    @AppStorage("showMemGraph") private var showMemGraph = true
    @AppStorage("floatingOpacity") private var opacity: Double = 0.9
    @State private var isHovering = false

    private var showMetricCards: Bool { showCPUGraph || showGPUGraph || showMemGraph }

    /// 플로팅 전용 모서리 반경 (v0.32.3) — TLRound.medium(10)은 타 화면 공용이라 분리.
    private static let corner: CGFloat = 24

    var body: some View {
        // NOTE: 실측 자동 높이(fitToContent)가 동작하려면 콘텐츠가 루트여야 한다.
        let cpu3 = cpuTop3
        let mem3 = memTop3
        Group {
            VStack(spacing: 0) {
                headerRow
                networkCard
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                if showMetricCards {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(TLPalette.separator)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    SystemMetricsCards(
                        detail: .compact,
                        cpuTop: cpu3,
                        memTop: mem3,
                        onShowProcesses: { openWindow(id: "appTraffic") },
                        backgroundOpacity: opacity
                    )
                    .padding(.horizontal, 12)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .fill(.regularMaterial)
                .opacity(opacity)
        )
        .overlay {
            if isHovering {
                RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if isHovering {
                HStack(spacing: 8) {
                    Menu {
                        Toggle(Localized.showCPUGraph, isOn: $showCPUGraph)
                        Toggle(Localized.showGPUGraph, isOn: $showGPUGraph)
                        Toggle(Localized.showMemGraph, isOn: $showMemGraph)
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help(Localized.floatingMetricsMenuHelp)

                    HStack(spacing: 6) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Slider(value: $opacity, in: 0.35...1.0)
                            .controlSize(.mini)
                        Text("\(Int(opacity * 100))%")
                            .font(TLFont.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(6)
            }
        }
        .frame(minWidth: 240)
        .onHover { isHovering = $0 }
    }

    // MARK: - 헤더 (드래그 영역)

    private var headerRow: some View {
        HStack {
            Circle()
                .fill(model.isReachable ? TLPalette.success : TLPalette.danger)
                .frame(width: 8, height: 8)
                .help(model.isReachable ? Localized.statusNormal : Localized.statusCritical)
            Spacer()
            if isHovering {
                Button {
                    FloatingWindowController.shared.toggle()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help(Localized.floatingWindowHide)
            }
        }
        .frame(height: 14)
        .padding(.horizontal, 12)
        .help(Localized.floatingDragHint)
    }

    // MARK: - 네트워크 카드 (항상 표시 — 팝오버 차트 + 프로세스 Top3)

    private var networkCard: some View {
        // sort/filter/share는 본문 1회만 — 행마다 재계산 방지 (v0.38.1)
        let top3 = networkTop3
        let share = Double(top3.reduce(Int64(0)) { $0 + $1.bytesIn + $1.bytesOut })
        return MetricCard(
            title: Localized.network,
            compact: true,
            backgroundOpacity: opacity
        ) {
            VStack(alignment: .leading, spacing: 6) {
                speedHeroRow
                TLNetworkSpeedChart(
                    history: networkMonitor.speedHistory,
                    uploadBitRate: networkMonitor.currentUploadSpeed,
                    downloadBitRate: networkMonitor.currentDownloadSpeed,
                    height: 64
                )
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(TLPalette.separator)
                processHeader
                if top3.isEmpty {
                    Text(Localized.trafficCollecting)
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 2)
                } else {
                    ForEach(top3) { app in
                        netRow(app, shareTotal: share)
                    }
                }
            }
        }
    }

    /// 팝오버 상단과 동일한 대형 업/다운 속도 (bit/s → split)
    private var speedHeroRow: some View {
        let up = Self.splitSpeed(networkMonitor.currentUploadSpeed)
        let down = Self.splitSpeed(networkMonitor.currentDownloadSpeed)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(up.number)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                    Text(up.unit)
                        .font(TLFont.caption)
                }
                .foregroundColor(TLPalette.upload)
                HStack(spacing: 3) {
                    Circle().fill(TLPalette.upload).frame(width: 6, height: 6)
                    Text(Localized.upload)
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(down.number)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                    Text(down.unit)
                        .font(TLFont.caption)
                }
                .foregroundColor(TLPalette.download)
                HStack(spacing: 3) {
                    Text(Localized.download)
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.textSecondary)
                    Circle().fill(TLPalette.download).frame(width: 6, height: 6)
                }
            }
        }
    }

    private static func splitSpeed(_ bps: Double) -> (number: String, unit: String) {
        let Bps = bps / 8
        if Bps >= 1_000_000_000 {
            return (String(format: "%.1f", Bps / 1_000_000_000), "GB/s")
        } else if Bps >= 1_000_000 {
            return (String(format: "%.1f", Bps / 1_000_000), "MB/s")
        } else if Bps >= 1_000 {
            return (String(format: "%.0f", Bps / 1_000), "KB/s")
        } else {
            return (String(format: "%.0f", Bps), "B/s")
        }
    }

    private var processHeader: some View {
        HStack(spacing: 4) {
            Text(Localized.process)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Localized.upload)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.upload)
                .lineLimit(1)
                .frame(minWidth: 56, alignment: .trailing)
            Text(Localized.download)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.download)
                .lineLimit(1)
                .frame(minWidth: 56, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 데이터 소스

    private var userApps: [TrafficMonitor.AppTraffic] {
        if showSystem { return trafficMonitor.apps }
        return trafficMonitor.apps.filter { !SystemProcesses.set.contains($0.processName) }
    }

    private var networkTop3: [TrafficMonitor.AppTraffic] {
        Array(userApps.sorted { ($0.bytesIn + $0.bytesOut) > ($1.bytesIn + $1.bytesOut) }.prefix(3))
    }

    private var cpuShareTotal: Double {
        cpuTop3.reduce(0) { $0 + max($1.res.cpuPercent ?? 0, 0) }
    }

    private var memShareTotal: Double {
        Double(trafficMonitor.systemLoad?.memTotalBytes ?? -1)
    }

    private var cpuTop3: [(name: String, res: ProcessResource)] {
        SystemResourceMonitor.topResources(userResources, limit: 3) { $0.cpuPercent ?? -1 }
    }

    private var memTop3: [(name: String, res: ProcessResource)] {
        SystemResourceMonitor.topResources(userResources, limit: 3) { Double($0.rssBytes) }
    }

    private var userResources: [String: ProcessResource] {
        if showSystem { return trafficMonitor.allResources }
        return trafficMonitor.allResources.filter { !SystemProcesses.set.contains($0.key) }
    }

    // MARK: - 행

    private func appIcon(_ name: String) -> some View {
        Group {
            if let nsImage = AppIconResolver.icon(forProcess: name) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app")
                    .foregroundColor(TLPalette.textSecondary)
            }
        }
        .frame(width: 14, height: 14)
    }

    private func netRow(_ app: TrafficMonitor.AppTraffic, shareTotal: Double) -> some View {
        let share = TLShare.ratio(Double(app.bytesIn + app.bytesOut), of: shareTotal)
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                appIcon(app.processName)
                Text(app.processName)
                    .font(TLFont.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(ByteRateFormat.string(app.bytesIn))
                    .font(TLFont.mediumMono)
                    .foregroundColor(TLPalette.upload)
                    .lineLimit(1)
                    .frame(minWidth: 56, alignment: .trailing)
                Text(ByteRateFormat.string(app.bytesOut))
                    .font(TLFont.mediumMono)
                    .foregroundColor(TLPalette.download)
                    .lineLimit(1)
                    .frame(minWidth: 56, alignment: .trailing)
            }
            TLShareBar(ratio: share, color: TLPalette.download)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { openWindow(id: "appTraffic") }
    }
}
