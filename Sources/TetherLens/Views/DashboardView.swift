import SwiftUI
import Combine

/// 대시보드 창 — 메뉴바 팝오버 `상세 보기` 를 대체하는 통합 관제 화면
///
/// **설계 원칙 (RelayConsole 대시보드 이식)**
/// - `Grid` + `GridRow` + `maxHeight: .infinity` — 카드 높이가 다른 행의 배경·테두리를 바닥까지 맞춘다.
///   (`LazyVGrid` 은 행 높이 제어가 불가능해 이 목적에 부적합)
/// - **이 뷰는 어떤 `@Published` 도 관찰하지 않는다.** 각 카드가 자기 데이터만 관찰하고,
///   `DashboardStore`(60초 DB 집계)만 상태바/KPI가 소비한다.
struct DashboardView: View {
    @ObservedObject private var store = DashboardStore.shared
    @Environment(\.openWindow) private var openWindow

    /// 카드 토글 변경 시 레이아웃만 갱신하기 위한 신호 (데이터 관찰 아님)
    @State private var cardConfigVersion = 0
    /// 배너 메시지 (할당량 경고)
    @State private var quotaAlert: String?

    /// 행 전체가 OFF 면 그 행 자체가 사라진다 (RelayConsole compactMap 패턴)
    private var visibleRows: [[DashboardCard]] {
        _ = cardConfigVersion  // 카드 토글 변경에 레이아웃만 반응
        return DashboardCard.rows
            .map { row in row.filter { SettingsManager.shared.isCardEnabled($0) } }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            DashboardStatusBar(
                profileName: store.snapshot.profileName,
                connectionTypeText: connectionTypeText,
                ssid: ssidText,
                rssi: AppServices.shared.hotspotDetector?.currentConnection?.rssi,
                isReachable: AppServices.shared.pingMonitor?.isReachable ?? true,
                sessionStart: store.snapshot.sessionStart,
                lastUpdated: store.snapshot.lastUpdated
            )

            Divider().overlay(TLPalette.separator.opacity(0.4))

            bannerStack

            Divider().overlay(TLPalette.separator.opacity(0.4))

            kpiRow

            Divider().overlay(TLPalette.separator.opacity(0.4))

            ScrollView {
                VStack(alignment: .leading, spacing: TLSpace.md) {
                    cardGrid
                }
                .padding(TLSize.dashboardInset)
            }

            Divider().overlay(TLPalette.separator.opacity(0.4))

            footer
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(TLPalette.windowBackground)
        .onAppear {
            store.acquire()
            TrafficMonitor.shared.acquire(reason: .floating)
        }
        .onDisappear {
            store.release()
            TrafficMonitor.shared.release(reason: .floating)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("settingsChanged"))) { _ in
            cardConfigVersion &+= 1
            // 프로필 편집·할당량 변경을 60초 대기 없이 반영
            store.refreshNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("quotaAlert"))) { n in
            quotaAlert = n.userInfo?["message"] as? String
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if quotaAlert == (n.userInfo?["message"] as? String) { quotaAlert = nil }
            }
        }
    }

    // MARK: - 2열 카드 그리드

    @ViewBuilder
    private var cardGrid: some View {
        let rows = visibleRows
        let wides = DashboardCard.wideCards.filter { SettingsManager.shared.isCardEnabled($0) }

        if !rows.isEmpty || !wides.isEmpty {
            VStack(alignment: .leading, spacing: TLSpace.md) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    // HStack(alignment: .top) + 카드의 maxHeight:.infinity 로 행 높이를 동기화한다.
                    // `Grid`/`GridRow` 은 자식의 `maxHeight: .infinity` 를 실제로 확장하지 않아
                    // 높이가 다른 카드가 같은 행에서 어긋난다(실측 확인).
                    HStack(alignment: .top, spacing: TLSpace.md) {
                        ForEach(row) { card in
                            cardView(card)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
                // 전폭 카드는 그리드 아래 한 줄 (RelayConsole wideCards 규칙)
                ForEach(wides) { card in
                    cardView(card)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func cardView(_ card: DashboardCard) -> some View {
        switch card {
        case .speed:   DashboardSpeedCard()
        case .quality: DashboardQualityCard()
        case .quota:   DashboardQuotaCard(onOpenReport: { openWindow(id: "usageReport") })
        case .pattern: DashboardPatternCard()
        case .cpu:     DashboardCpuCard()
        case .gpu:     DashboardGpuCard()
        case .memory:  DashboardMemoryCard()
        case .process: DashboardProcessCard(onShowProcesses: { openWindow(id: "appTraffic") })
        case .insight: DashboardInsightCard(
            onShowAppTraffic: { openWindow(id: "appTraffic") },
            onOpenDiagnostics: { DiagnosticsWindowController.shared.show() }
        )
        }
    }

    // MARK: - 배너

    @ViewBuilder
    private var bannerStack: some View {
        let ping = AppServices.shared.pingMonitor
        let notReachable = !(ping?.isReachable ?? true)
        if notReachable {
            banner(Localized.connectionLost, symbol: "wifi.exclamationmark", color: TLPalette.danger)
        }
        if let quotaAlert {
            banner(quotaAlert, symbol: "exclamationmark.triangle.fill", color: TLPalette.upload)
        }
    }

    private func banner(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: TLSpace.sm) {
            Image(systemName: symbol).font(TLFont.badge).foregroundColor(color)
            Text(text)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textPrimary)
                .lineLimit(2)
            Spacer(minLength: TLSpace.md)
            Button {
                if quotaAlert != nil { quotaAlert = nil }
            } label: {
                Image(systemName: "xmark").font(TLFont.badge).foregroundColor(TLPalette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, TLSize.dashboardInset)
        .padding(.vertical, TLSpace.sm)
        .background(color.opacity(0.12))
    }

    // MARK: - KPI

    private var kpiRow: some View {
        let s = store.snapshot
        return HStack(spacing: TLSpace.md) {
            kpiCell(
                Localized.todayUsage,
                s.hasTodayUsage ? Self.gb(s.todayUsedGB) : "—",
                sub: s.quotaGB.map { quota in Self.percent(s.todayUsedGB / max(quota, 0.001)) } ?? nil,
                sub2: s.quotaGB.map { q in Self.gb(max(q - s.todayUsedGB, 0)) + " " + Localized.remainingLabel },
                color: s.hasTodayUsage ? TLPalette.textPrimary : TLPalette.copyHint
            )
            divider
            kpiCell(Localized.upload, s.todayUpload > 0 ? Self.bytes(s.todayUpload) : "—",
                    sub: s.hasTodayUsage ? Self.percent(Double(s.todayUpload) / Double(max(s.todayTotal, 1))) : nil,
                    sub2: nil, color: TLPalette.upload)
            divider
            kpiCell(Localized.download, s.todayDownload > 0 ? Self.bytes(s.todayDownload) : "—",
                    sub: s.hasTodayUsage ? Self.percent(Double(s.todayDownload) / Double(max(s.todayTotal, 1))) : nil,
                    sub2: nil, color: TLPalette.download)
            divider
            kpiCell(Localized.remainingLabel, remainingText, sub: nil, sub2: nil,
                    color: s.hasProfile ? TLPalette.textPrimary : TLPalette.copyHint)
            divider
            kpiCell(Localized.string("오늘 세션", "Today Sessions"),
                    s.sessionCount > 0 ? "\(s.sessionCount)" : "—",
                    sub: s.sessionCount > 0 ? Self.hms(s.sessionDuration) : nil, sub2: nil,
                    color: s.sessionCount > 0 ? TLPalette.textPrimary : TLPalette.copyHint)
        }
        .padding(.horizontal, TLSize.dashboardInset)
        .padding(.vertical, TLSpace.md)
    }

    private var divider: some View {
        Rectangle().fill(TLPalette.separator.opacity(0.3)).frame(width: 1, height: 30)
    }

    private var remainingText: String {
        guard let quota = store.snapshot.quotaGB, quota > 0 else { return "—" }
        return Self.gb(max(quota - store.snapshot.todayUsedGB, 0))
    }

    private func kpiCell(_ title: String, _ value: String, sub: String?, sub2: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary)
            Text(value)
                .font(TLFont.dashboardValue)
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let sub2 {
                Text(sub2).font(TLFont.badge).foregroundColor(TLPalette.copyHint).lineLimit(1)
            } else if let sub {
                Text(sub).font(TLFont.badge).foregroundColor(TLPalette.copyHint).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 푸터

    private var footer: some View {
        HStack(spacing: TLSpace.md) {
            footerButton(Localized.settings, symbol: "gearshape") { openSettings() }
            footerButton(Localized.networkDiagnostics, symbol: "stethoscope") {
                DiagnosticsWindowController.shared.show()
            }
            footerButton(Localized.usageReport, symbol: "chart.bar.fill") { openWindow(id: "usageReport") }
            footerButton(Localized.appTrafficButton, symbol: "arrow.up.arrow.down") { openWindow(id: "appTraffic") }
            Spacer(minLength: TLSpace.md)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power").font(TLFont.badge).foregroundColor(TLPalette.danger)
            }
            .buttonStyle(.plain)
            .help(Localized.quit)
        }
        .padding(.horizontal, TLSize.dashboardInset)
        .padding(.vertical, TLSpace.sm)
    }

    private func footerButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(TLFont.badge)
                Text(title).font(TLFont.caption2)
            }
            .foregroundColor(TLPalette.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 연결 정보 (비발행 값 — body 평가 시 1회만 읽는다)

    private var connectionTypeText: String {
        guard let c = AppServices.shared.hotspotDetector?.currentConnection else {
            return Localized.string("연결 없음", "Not connected")
        }
        return DashboardDetailCard.typeText(c)
    }

    private var ssidText: String? {
        guard let c = AppServices.shared.hotspotDetector?.currentConnection else { return nil }
        switch c.type {
        case .normalWiFi(let ssid, _): return ssid
        case .iOSPersonalHotspot(let ssid): return ssid
        case .androidHotspot(let ssid): return ssid
        case .ethernet, .unknown: return nil
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: TLSpace.md) {
            Image(systemName: "rectangle.3.offgrid")
                .font(.system(size: 28))
                .foregroundColor(TLPalette.copyHint)
            Text(Localized.string("표시할 카드가 없습니다", "No cards enabled"))
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 포맷 (전부 static — 생성 비용 제거)

    static func bytes(_ v: Int64) -> String { v.formattedBytes }
    static func gb(_ v: Double) -> String { v >= 1 ? String(format: "%.2fGB", v) : String(format: "%.0fMB", v * 1000) }
    static func percent(_ ratio: Double) -> String { String(format: "%.0f%%", min(max(ratio * 100, 0), 999)) }
    static func hms(_ t: TimeInterval) -> String {
        let total = max(Int(t), 0)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, total % 60) : String(format: "%d:%02d", m, total % 60)
    }
}
