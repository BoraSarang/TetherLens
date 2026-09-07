import SwiftUI

/// 플로팅 창 본체 — 메뉴바 표시(설정 동일 반영) + 3줄 요약(프로세스/CPU/RAM 각 1위).
/// borderless NSPanel(NonActivating, resizable) 안에서 호스팅된다 (FloatingWindowController 소유).
/// 콘텐츠는 상단 정렬이고 배경(material)이 패널 크기를 채워 리사이즈에 대응한다.
struct FloatingWindowView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: FloatingWindowViewModel
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @AppStorage("floatingShowProcess") private var showProcess = true
    @AppStorage("floatingShowCPU") private var showCPU = true
    @AppStorage("floatingShowRAM") private var showRAM = true
    @AppStorage("floatingShowUsage") private var showUsage = true
    @AppStorage("floatingOpacity") private var opacity: Double = 0.9
    @State private var isHovering = false

    private var anyLine: Bool { showProcess || showCPU || showRAM }

    var body: some View {
        // NOTE: 실측 자동 높이(fitToContent)가 동작하려면 콘텐츠가 루트여야 한다.
        // RoundedRectangle + .overlay{콘텐츠} 구조에서는 overlay가 ideal size에 기여하지 않아
        // fittingSize가 붕괴한다. 배경·테두리는 background/overlay로만 둔다.
        Group {
            if anyLine {
                fullLayout
            } else {
                compactLayout
            }
        }
        .background(
            RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous)
                .fill(.regularMaterial)
                .opacity(opacity)
        )
            .overlay {
                RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                // 호버 시 투명도 직접 조절 (설정 창과 동일 키·범위, 레이아웃 불변)
                if isHovering {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(6)
                }
            }
            .frame(minWidth: 220)
            .onHover { isHovering = $0 }
    }

    /// 3칸 ON — 닫기 버튼 + 속도 2줄 + 사용량 중앙 + 프로세스/CPU/RAM Top3 (높이는 자동 맞춤)
    private var fullLayout: some View {
        return VStack(spacing: 0) {
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

            menuBarMini
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(TLPalette.separator)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)

            blocksView
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    /// 줄 전부 OFF — 속도·사용량 한 줄 컴팩트 (세로 40)
    private var compactLayout: some View {
        let fontSize = SettingsManager.shared.menuBarFontSize
        return HStack(spacing: 10) {
            Circle()
                .fill(model.isReachable ? TLPalette.success : TLPalette.danger)
                .frame(width: 8, height: 8)
                .help(model.isReachable ? Localized.statusNormal : Localized.statusCritical)
            speedColumn(icon: "arrow.up", value: model.upSpeed, color: TLPalette.upload, size: fontSize, alignment: .trailing)
            usageColumn(fontSize: fontSize)
            speedColumn(icon: "arrow.down", value: model.downSpeed, color: TLPalette.download, size: fontSize, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .overlay(alignment: .topTrailing) {
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
    }

    // MARK: - 메뉴바 표시 (다운·사용량·업)

    /// 업/다운은 양 끝, 네트워크 사용량(또는 SSID 등 col3)은 중앙 정렬.
    private var menuBarMini: some View {
        let fontSize = SettingsManager.shared.menuBarFontSize
        return HStack(spacing: 12) {
            speedColumn(icon: "arrow.up", value: model.upSpeed, color: TLPalette.upload, size: fontSize, alignment: .trailing)
            usageColumn(fontSize: fontSize)
            speedColumn(icon: "arrow.down", value: model.downSpeed, color: TLPalette.download, size: fontSize, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private func speedColumn(icon: String, value: String, color: Color, size: Double, alignment: Alignment) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: size + 1, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .fixedSize()
        }
        // 속도 값의 자리수 변화에도 좌/우 위치 흔들림을 줄이되, 좌우 오버플로우 없이 최소 폭만 보장
        .frame(minWidth: 70, alignment: alignment)
    }

    /// col3 중앙 표시 — 할당량 설정 시 사용량/잔여(비율 색), 그 외 RSSI(top) + 지연시간(bottom).
    @ViewBuilder
    private func usageColumn(fontSize: Double) -> some View {
        if model.col3IsLatency {
            VStack(spacing: 2) {
                Text(model.col3Top)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(MenuBarManager.rssiColor(model.rssi >= -1000 ? model.rssi : nil))
                Text(model.col3Bottom)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(MenuBarManager.latencyColor(model.latencyMS >= 0 ? Double(model.latencyMS) / 1000.0 : nil))
            }
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .center)
        } else if model.totalRatio >= 0 && (!model.col3IsUsage || showUsage) {
            VStack(spacing: 2) {
                Text(model.col3Top)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(ratioColor)
                Text(model.col3Bottom)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(ratioColor)
            }
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var ratioColor: Color {
        let green = SavingModeManager.shared.greenThreshold
        let orange = SavingModeManager.shared.orangeThreshold
        if model.totalRatio < green {
            return TLPalette.success
        } else if model.totalRatio < orange {
            return TLPalette.upload
        } else {
            return TLPalette.danger
        }
    }

    // MARK: - 3칸 (프로세스/CPU/RAM 각 Top3, v0.32.2)

    /// 켜진 칸만 표시 — 같은 스냅샷을 기준별로 정렬하므로 추가 폴링 없음.
    @ViewBuilder
    private var blocksView: some View {
        if trafficMonitor.apps.isEmpty && trafficMonitor.allResources.isEmpty {
            HStack {
                Spacer()
                Text(Localized.trafficCollecting)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            }
            .padding(.vertical, 2)
        } else {
            VStack(spacing: 6) {
                if showProcess, !networkTop3.isEmpty {
                    VStack(spacing: 0) {
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
                                .frame(minWidth: 64, maxWidth: 96, alignment: .trailing)
                            Text(Localized.download)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.download)
                                .lineLimit(1)
                                .frame(minWidth: 72, maxWidth: 100, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity)
                        ForEach(networkTop3) { app in
                            netRow(app)
                        }
                    }
                }
                if showCPU, !cpuTop3.isEmpty {
                    blockSection(title: Localized.cpu) {
                        ForEach(cpuTop3, id: \.name) { entry in
                            cpuRow(entry)
                        }
                    }
                }
                if showRAM, !memTop3.isEmpty {
                    blockSection(title: Localized.memory) {
                        ForEach(memTop3, id: \.name) { entry in
                            memRow(entry)
                        }
                    }
                }
            }
        }
    }

    private var userApps: [TrafficMonitor.AppTraffic] {
        trafficMonitor.apps.filter { !SystemProcesses.set.contains($0.processName) }
    }

    private var networkTop3: [TrafficMonitor.AppTraffic] {
        Array(userApps.sorted { ($0.bytesIn + $0.bytesOut) > ($1.bytesIn + $1.bytesOut) }.prefix(3))
    }

    /// 전체 프로세스 기준 CPU Top3 — 네트워크 무관, 시스템 제외 (v0.32.4).
    private var cpuTop3: [(name: String, res: ProcessResource)] {
        SystemResourceMonitor.topResources(userResources, limit: 3) { $0.cpuPercent ?? -1 }
    }

    /// 전체 프로세스 기준 메모리 Top3 — 네트워크 무관, 시스템 제외 (v0.32.4).
    private var memTop3: [(name: String, res: ProcessResource)] {
        SystemResourceMonitor.topResources(userResources, limit: 3) { Double($0.rssBytes) }
    }

    private var userResources: [String: ProcessResource] {
        trafficMonitor.allResources.filter { !SystemProcesses.set.contains($0.key) }
    }

    private func blockSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }

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

    private func symIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 11))
            .foregroundColor(TLPalette.textSecondary)
            .frame(width: 14)
    }

    private func netRow(_ app: TrafficMonitor.AppTraffic) -> some View {
        HStack(spacing: 4) {
            appIcon(app.processName)
            Text(app.processName)
                .font(TLFont.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatByteRate(app.bytesIn))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.upload)
                .lineLimit(1)
                .frame(minWidth: 64, maxWidth: 96, alignment: .trailing)
            Text(formatByteRate(app.bytesOut))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.download)
                .lineLimit(1)
                .frame(minWidth: 72, maxWidth: 100, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { openWindow(id: "appTraffic") }
    }

    private func cpuRow(_ entry: (name: String, res: ProcessResource)) -> some View {
        HStack(spacing: 4) {
            symIcon("cpu")
            Text(entry.name)
                .font(TLFont.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(SystemResourceMonitor.formatCPU(entry.res.cpuPercent))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.cpuHeat(entry.res.cpuPercent))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { openWindow(id: "appTraffic") }
    }

    private func memRow(_ entry: (name: String, res: ProcessResource)) -> some View {
        HStack(spacing: 4) {
            symIcon("memorychip")
            Text(entry.name)
                .font(TLFont.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(SystemResourceMonitor.formatMemory(entry.res.rssBytes))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { openWindow(id: "appTraffic") }
    }

    private func formatByteRate(_ bytesPerSecond: Int64) -> String {
        let bps = Double(bytesPerSecond)
        if bps >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bps / 1_000_000_000)
        } else if bps >= 1_000_000 {
            return String(format: "%.1f MB/s", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.1f KB/s", bps / 1_000)
        } else {
            return String(format: "%.0f B/s", bps)
        }
    }
}