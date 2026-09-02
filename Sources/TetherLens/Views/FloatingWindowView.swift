import SwiftUI

/// 플로팅 창 본체 — 메뉴바 표시(설정 동일 반영) + 프로세스 트래픽 상위 3개.
/// borderless NSPanel(NonActivating, resizable) 안에서 호스팅된다 (FloatingWindowController 소유).
/// 콘텐츠는 상단 정렬이고 배경(material)이 패널 크기를 채워 리사이즈에 대응한다.
struct FloatingWindowView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: FloatingWindowViewModel
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @AppStorage("floatingShowTraffic") private var showTraffic = true
    @AppStorage("floatingShowUsage") private var showUsage = true
    @AppStorage("floatingOpacity") private var opacity: Double = 0.9
    @State private var isHovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous)
            .fill(.regularMaterial)
            .opacity(opacity)
            .overlay {
                if showTraffic {
                    fullLayout
                } else {
                    compactLayout
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .frame(minWidth: 220)
            .onHover { isHovering = $0 }
    }

    /// 프로세스 리스트 ON — 닫기 버튼 + 속도 2줄 + 사용량 중앙 + 트래픽 목록 (세로 120)
    private var fullLayout: some View {
        let fontSize = SettingsManager.shared.menuBarFontSize
        return VStack(spacing: 0) {
            HStack {
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

            menuBarMini
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            trafficSection
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    /// 프로세스 리스트 OFF — 속도·사용량 한 줄 컴팩트 (세로 30)
    private var compactLayout: some View {
        let fontSize = SettingsManager.shared.menuBarFontSize
        return HStack(spacing: 10) {
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

    /// 사용량/잔여 — "네트워크 사용량"이면 중앙 정렬 + 토글로 제어, SSID·BSSID·링크속도면 항상 표시.
    @ViewBuilder
    private func usageColumn(fontSize: Double) -> some View {
        let show = model.totalRatio >= 0 && (!model.col3IsUsage || showUsage)
        if show {
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

    // MARK: - 프로세스 트래픽 (상위 3, 시스템 제외)

    @ViewBuilder
    private var trafficSection: some View {
        if showTraffic {
            if trafficMonitor.apps.isEmpty {
                HStack {
                    Spacer()
                    Text(Localized.trafficCollecting)
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 2)
            } else {
                VStack(spacing: 0) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(TLPalette.separator)
                        .padding(.bottom, 4)
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
                    ForEach(top3) { app in
                        trafficRow(app)
                    }
                }
            }
        }
    }

    private var top3: [TrafficMonitor.AppTraffic] {
        Array(trafficMonitor.apps.filter { !SystemProcesses.set.contains($0.processName) }.prefix(3))
    }

    private func trafficRow(_ app: TrafficMonitor.AppTraffic) -> some View {
        HStack(spacing: 4) {
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