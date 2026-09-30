import SwiftUI
import Combine

// MARK: - 상태바

/// 대시보드 상단 상태바 — 연결 상태 요약
///
/// **갱신 규칙**: 초 단위(세션 경과·상대 시각)는 `DashboardClock` 서브뷰가 자체 타이머로 담당한다.
/// 이 뷰 자체는 데이터를 관찰하지 않으므로 어떤 1초 틱에도 body 가 재평가되지 않는다.
struct DashboardStatusBar: View {
    let profileName: String?
    let connectionTypeText: String
    let ssid: String?
    let rssi: Int?
    let isReachable: Bool
    let sessionStart: Date?
    let lastUpdated: Date

    private var statusColor: Color {
        if !isReachable { return TLPalette.danger }
        return TLPalette.success
    }

    var body: some View {
        HStack(spacing: TLSpace.md) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(TLFont.medium)
                .foregroundColor(TLPalette.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(titleText)
                    .font(TLFont.body.bold())
                    .foregroundColor(TLPalette.textPrimary)
                    .lineLimit(1)
                Text(subtitleText)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: TLSpace.md)

            DashboardClock(sessionStart: sessionStart, lastUpdated: lastUpdated)
        }
        .padding(.horizontal, TLSize.dashboardInset)
        .padding(.vertical, TLSpace.md)
    }

    private var titleText: String {
        let name = profileName ?? connectionTypeText
        return name
    }

    private var subtitleText: String {
        var parts: [String] = [connectionTypeText]
        if let ssid { parts.append(ssid) }
        if let rssi { parts.append("\(rssi)dBm") }
        return parts.joined(separator: " · ")
    }
}

/// 세션 경과 + 마지막 갱신 상대 시각 — **자체 1초 타이머**
///
/// 감사에서 확인된 결함(팝오버 1Hz tick이 body 전체를 재렌더)을 피하기 위해
/// 초 단위 표시를 이 작은 서브뷰로 격리했다. 대시보드 본체는 1초 틱에 참여하지 않는다.
struct DashboardClock: View {
    let sessionStart: Date?
    let lastUpdated: Date

    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: TLSpace.md) {
            if let sessionStart {
                Label {
                    Text(Self.durationString(since: sessionStart, now: now))
                        .font(TLFont.mediumMono)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "clock").font(TLFont.badge)
                }
                .foregroundColor(TLPalette.textSecondary)
            }

            Label {
                Text(Localized.relativeSeconds(Int(now.timeIntervalSince(lastUpdated))))
                    .font(TLFont.caption2)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "arrow.clockwise").font(TLFont.badge)
            }
            .foregroundColor(TLPalette.copyHint)
        }
        .onReceive(ticker) { now = $0 }
    }

    /// `H:MM:SS` / `MM:SS`
    static func durationString(since start: Date, now: Date) -> String {
        let total = max(Int(now.timeIntervalSince(start)), 0)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - KPI (전폭)

// MARK: - ① 실시간 속도

/// ① 실시간 속도 — 차트 + 큰 숫자 + Top3 앱
///
/// `@ObservedObject NetworkMonitor` 를 **이 카드만** 관찰한다.
struct DashboardSpeedCard: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var onShowProcesses: (() -> Void)?

    var body: some View {
        MetricCard(title: DashboardCard.speed.title, fillsRow: true) {
            VStack(alignment: .leading, spacing: TLSpace.md) {
                HStack(alignment: .firstTextBaseline, spacing: TLSpace.xl) {
                    speedValue(networkMonitor.currentUploadSpeed, color: TLPalette.upload, label: Localized.upload)
                    Spacer(minLength: TLSpace.md)
                    speedValue(networkMonitor.currentDownloadSpeed, color: TLPalette.download, label: Localized.download)
                }

                TLNetworkSpeedChart(
                    history: networkMonitor.speedHistory,
                    uploadBitRate: networkMonitor.currentUploadSpeed,
                    downloadBitRate: networkMonitor.currentDownloadSpeed
                )
                .frame(height: 88)

                topApps
            }
        }
    }

    private func speedValue(_ bps: Double, color: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(Self.rateString(bps))
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary)
            }
        }
    }

    /// Top3 앱 — 점유율 바 (RelayConsole 카드 리듬: 값 → 바 → 상세행)
    @ViewBuilder
    private var topApps: some View {
        DashboardAppTop3()
    }

    /// bps → "1.2 MB/s" (BinaryFormatter 와 동일 규약)
    static func rateString(_ bps: Double) -> String {
        let bytesPerSec = bps / 8
        if bytesPerSec >= 1_000_000_000 { return String(format: "%.2f GB/s", bytesPerSec / 1_000_000_000) }
        if bytesPerSec >= 1_000_000 { return String(format: "%.1f MB/s", bytesPerSec / 1_000_000) }
        if bytesPerSec >= 1_000 { return String(format: "%.0f KB/s", bytesPerSec / 1_000) }
        return String(format: "%.0f B/s", bytesPerSec)
    }
}

/// 속도 카드 하단 Top3 앱 — `TrafficMonitor` 만 관찰
private struct DashboardAppTop3: View {
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared

    private var top3: [TrafficMonitor.AppTraffic] {
        Array(trafficMonitor.apps.prefix(3))
    }

    /// `AppTraffic` 값은 **측정 구간(≈ trafficMonitorInterval 초)의 합계**다.
    /// "실시간 속도" 카드이므로 초당 값으로 나눠야 한다 (v0.38.3에서 samples를
    /// 재조회 주기에 맞췄으므로 구간 길이 == interval).
    private var windowSeconds: Double {
        max(SettingsManager.shared.trafficMonitorInterval, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if top3.isEmpty {
                // 값이 없는 지표를 0으로 그리지 않는다 (RelayConsole 원칙 5)
                Text(Localized.trafficCollecting)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.copyHint)
            } else {
                let total = top3.reduce(Int64(0)) { $0 + $1.bytesIn + $1.bytesOut }
                ForEach(top3) { app in
                    HStack(spacing: TLSpace.sm) {
                        Text(app.processName)
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: TLSpace.sm)
                        Text(Self.rate(Double(app.bytesIn + app.bytesOut) / windowSeconds))
                            .font(TLFont.badgeMono)
                            .foregroundColor(TLPalette.textSecondary)
                            .monospacedDigit()
                        TLShareBar(ratio: TLShare.ratio(Double(app.bytesIn + app.bytesOut), of: Double(max(total, 1))), color: TLPalette.download)
                            .frame(width: 64)
                    }
                }
            }
        }
    }

    /// 초당 바이트 → "26.7MB/s"
    private static func rate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_000_000_000 { return String(format: "%.2fGB/s", bytesPerSec / 1_000_000_000) }
        if bytesPerSec >= 1_000_000 { return String(format: "%.1fMB/s", bytesPerSec / 1_000_000) }
        if bytesPerSec >= 1_000 { return String(format: "%.0fKB/s", bytesPerSec / 1_000) }
        return String(format: "%.0fB/s", bytesPerSec)
    }
}

// MARK: - ② 연결 품질

/// ② 연결 품질 — RTT·지터·패킷손실·신호
///
/// `PingMonitor` 는 `@Published` 가 없으므로 **이 카드가 자체 5초 타이머**를 소유한다.
struct DashboardQualityCard: View {
    @State private var now = Date()
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var ping: PingMonitor? { AppServices.shared.pingMonitor }

    private var connection: ConnectionInfo? {
        AppServices.shared.hotspotDetector?.currentConnection
    }

    var body: some View {
        MetricCard(title: DashboardCard.quality.title, fillsRow: true) {
            VStack(alignment: .leading, spacing: TLSpace.sm) {
                HStack(spacing: TLSpace.lg) {
                    metric(Localized.gateway, ping?.gatewayRTT, color: TLPalette.textPrimary)
                    metric("8.8.8.8", ping?.dnsRTT, color: TLPalette.textPrimary)
                    metric(Localized.jitterTitle, ping?.jitter, color: TLPalette.textPrimary)
                    Spacer(minLength: 0)
                }

                pingDots

                Divider().overlay(TLPalette.separator.opacity(0.4))

                wifiRows

                Divider().overlay(TLPalette.separator.opacity(0.4))

                healthRows

                Divider().overlay(TLPalette.separator.opacity(0.4))

                latencyTrend
                Spacer(minLength: 0)
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    /// 카드 하단 — **실측 지연 기록**의 추이. ① 속도 카드의 차트가 행 높이를 결정해
    /// ② 하단이 비어 보이는데, 장식으로 채우지 않고 값 있는 정보(지연 추이 + 최소/평균/최대)를 넣는다.
    /// 미측정이면 0으로 그리지 않고 "측정 중"으로 표기한다.
    @ViewBuilder
    private var latencyTrend: some View {
        let samples = ping?.recentLatencies ?? []
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: TLSpace.sm) {
                Text(Localized.latencyTrend)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.copyHint)
                Spacer(minLength: TLSpace.sm)
                if let stat = latencyStat(samples) {
                    Text("min \(Self.ms(stat.min)) · avg \(Self.ms(stat.avg)) · max \(Self.ms(stat.max))")
                        .font(TLFont.badgeMono)
                        .foregroundColor(TLPalette.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            if samples.isEmpty {
                Text(Localized.measuring)
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.copyHint)
            } else {
                TLSparkline(points: samples, color: TLPalette.download, height: 22)
            }
        }
    }

    private func latencyStat(_ samples: [TimeInterval]) -> (min: TimeInterval, avg: TimeInterval, max: TimeInterval)? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0, +)
        return (samples.min() ?? 0, sum / Double(samples.count), samples.max() ?? 0)
    }

    private static func ms(_ t: TimeInterval) -> String { "\(Int(t * 1000))ms" }

    /// 패킷 손실 · 경고 · 자동화 · 절약모드 — 카드 하단 상태 요약
    @ViewBuilder
    private var healthRows: some View {
        let outcomes = ping?.recentPingOutcomes ?? []
        let loss = outcomes.isEmpty ? nil : Double(outcomes.filter { !$0 }.count) / Double(outcomes.count) * 100

        HStack(spacing: TLSpace.md) {
            statusPill(
                loss.map { "\(Int((100 - $0).rounded()))%" },
                label: Localized.string("정상 응답", "OK"),
                color: (loss ?? 0) > 0 ? TLPalette.upload : TLPalette.success
            )
            let active = NotificationManager.shared.activeWarnings.count
            if active > 0 {
                statusPill("\(active)", label: Localized.string("미해소 경고", "Open alerts"), color: TLPalette.danger)
            }
            let rules = AutomationManager.shared.rules.filter(\.isEnabled).count
            if rules > 0 {
                statusPill("\(rules)", label: Localized.automation, color: TLPalette.accent)
            }
            Spacer(minLength: 0)
        }
    }

    /// `value` 가 nil 이면 값 칸을 "—" 로 대체한다 (미측정을 0으로 보이지 않게)
    private func statusPill(_ value: String?, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(value ?? "—").font(TLFont.badgeMono).foregroundColor(color).monospacedDigit()
            Text(label).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary).lineLimit(1)
        }
    }

    /// RTT 1행 — nil 은 "미측정"으로 표기 (0으로 뭉개지 않는다)
    private func metric(_ label: String, _ value: TimeInterval?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary)
            Text(value.map { "\(Int($0 * 1000))ms" } ?? "—")
                .font(TLFont.mediumMono)
                .monospacedDigit()
                .foregroundColor(value == nil ? TLPalette.copyHint : color)
        }
    }

    /// 최근 20회 성공/실패 도트
    @ViewBuilder
    private var pingDots: some View {
        let outcomes = ping?.recentPingOutcomes.suffix(20) ?? []
        if outcomes.isEmpty {
            Text(Localized.measuring)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.copyHint)
        } else {
            HStack(spacing: 3) {
                ForEach(Array(outcomes.enumerated()), id: \.offset) { _, ok in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ok ? TLPalette.success : TLPalette.separator)
                        .frame(width: 8, height: 8)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var wifiRows: some View {
        if let c = connection, c.type != .unknown {
            VStack(alignment: .leading, spacing: 2) {
                if let link = c.linkSpeed {
                    detailRow(Localized.linkSpeedLabel, "\(Int(link)) Mbps", color: TLPalette.textSecondary)
                }
                if let ch = c.channel {
                    let band = c.channelBand.map { " \($0)" } ?? ""
                    let width = c.channelWidth.map { " \($0)MHz" } ?? ""
                    detailRow(Localized.channel, "\(ch)\(band)\(width)", color: TLPalette.textSecondary)
                }
                if let phy = c.phyMode {
                    detailRow(Localized.standard, phy, color: TLPalette.textSecondary)
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: TLSpace.sm) {
            Text(label).font(TLFont.caption2).foregroundColor(TLPalette.copyHint)
            Spacer(minLength: TLSpace.sm)
            Text(value).font(TLFont.caption2).foregroundColor(color).monospacedDigit()
        }
    }
}

// MARK: - ③ 할당량 · 예측

/// ③ 할당량 · 예측 — QoS 게이지 + 오늘/예측
/// `DashboardStore` 만 관찰 (60초 주기)
struct DashboardQuotaCard: View {
    @ObservedObject private var store = DashboardStore.shared

    var onOpenReport: (() -> Void)?

    private var s: DashboardStore.Snapshot { store.snapshot }

    var body: some View {
        MetricCard(title: DashboardCard.quota.title, fillsRow: true) {
            VStack(alignment: .leading, spacing: TLSpace.sm) {
                if let quota = s.quotaGB, quota > 0 {
                    QoSGauge(used: s.todayUsedGB, total: quota)

                    HStack(spacing: TLSpace.md) {
                        kpi(Localized.todayUsage, Self.gb(s.todayUsedGB), color: TLPalette.textSecondary)
                        Spacer(minLength: 0)
                        if let pace = paceText {
                            Text(pace)
                                .font(TLFont.caption2)
                                .foregroundColor(TLPalette.copyHint)
                        }
                    }

                    Divider().overlay(TLPalette.separator.opacity(0.35))

                    if let cmp = vsAverageText {
                        Text(cmp.text)
                            .font(TLFont.caption2)
                            .foregroundColor(cmp.color)
                            .lineLimit(1)
                    }
                    HStack(spacing: TLSpace.md) {
                        kpi(Localized.string("최근 8일 합계", "Last 8d sum"),
                            s.dailyTotals.isEmpty ? "—" : DashboardView.bytes(s.dailyTotals.reduce(0, +)))
                        Spacer(minLength: 0)
                        kpi(Localized.string("일평균", "Daily avg"),
                            s.dailyTotals.isEmpty ? "—" : DashboardView.bytes(average8d))
                    }
                    Spacer(minLength: 0)
                } else {
                    // 할당량 미설정 = 0 이 아니라 "설정 없음" 상태로 표기
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localized.noQuota)
                            .font(TLFont.caption)
                            .foregroundColor(TLPalette.textSecondary)
                        Text(Localized.todayUsage + " " + Self.gb(s.todayUsedGB))
                            .font(TLFont.mediumMono)
                            .foregroundColor(TLPalette.textPrimary)
                    }
                    if onOpenReport != nil {
                        linkButton
                    }
                }
            }
        }
    }

    /// 오늘을 기준으로 "내일 자정까지 현재 속도면 N%" 예측
    private var paceText: String? {
        guard let quota = s.quotaGB, quota > 0, s.hasTodayUsage else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let elapsedHours = max(Date().timeIntervalSince(startOfDay) / 3600, 0.25)
        let projected = s.todayUsedGB / elapsedHours * 24
        if projected < quota { return nil }
        return Localized.projectedTomorrow(Int(min(projected / quota, 9.99) * 100))
    }

    private func kpi(_ label: String, _ value: String, color: Color = TLPalette.textSecondary) -> some View {
        HStack(spacing: 3) {
            Text(label).font(TLFont.caption2).foregroundColor(TLPalette.textSecondary)
            Text(value).font(TLFont.badgeMono).foregroundColor(color).monospacedDigit()
        }
    }

    private var linkButton: some View {
        Button {
            onOpenReport?()
        } label: {
            HStack(spacing: 2) {
                Text(Localized.usageReport)
                Image(systemName: "chevron.right").font(TLFont.badge)
            }
            .font(TLFont.caption2)
            .foregroundColor(TLPalette.accent)
        }
        .buttonStyle(.plain)
    }

    static func gb(_ value: Double) -> String {
        value >= 1 ? String(format: "%.2fGB", value) : String(format: "%.0fMB", value * 1000)
    }

    /// 최근 8일 일평균 (오늘 포함)
    private var average8d: Int64 {
        s.dailyTotals.isEmpty ? 0 : s.dailyTotals.reduce(0, +) / Int64(s.dailyTotals.count)
    }

    /// 오늘 vs 8일 평균 비교
    private var vsAverageText: (text: String, color: Color)? {
        let avg = average8d
        guard avg > 0, s.hasTodayUsage else { return nil }
        let ratio = Double(s.todayTotal) / Double(avg)
        let up = ratio >= 1
        return (
            String(format: Localized.string("8일 평균 대비 %.1f배", "%.1fx vs 8d avg"), ratio),
            ratio >= 2 ? TLPalette.danger : (up ? TLPalette.upload : TLPalette.success)
        )
    }
}

// MARK: - ⑦ 연결 상세 (전폭)

/// ⑦ 연결 상세 — 전폭 1행 카드. `HotspotDetector` 비발행 값 → 자체 5초 타이머.
struct DashboardDetailCard: View {
    @State private var now = Date()
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    @ObservedObject private var store = DashboardStore.shared

    private var connection: ConnectionInfo? {
        AppServices.shared.hotspotDetector?.currentConnection
    }

    private var externalIP: String? {
        AppServices.shared.ipResolver?.externalIP
    }

    var body: some View {
        MetricCard(title: Localized.string("연결 상세", "Connection Detail")) {
            VStack(alignment: .leading, spacing: TLSpace.sm) {
                flowRow
                Divider().overlay(TLPalette.separator.opacity(0.4))
                flagsRow
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    /// 유형 · SSID · BSSID · 로컬IP · 게이트웨이 · 외부IP · DNS
    @ViewBuilder
    private var flowRow: some View {
        if let c = connection {
            FlowRow(spacing: TLSpace.md) {
                chip(DashboardCard.speed.title == "" ? "" : Self.typeText(c), symbol: "network")
                if case .normalWiFi(let ssid, let bssid) = c.type {
                    if let ssid { chip(ssid, symbol: "wifi") }
                    if let bssid { chip(bssid, symbol: "dot.radiowaves.right") }
                }
                if let mac = Self.mac(interface: c.interfaceName) { chip(mac, symbol: "number") }
                if let ip = c.localIP { chip(ip, symbol: "desktopcomputer") }
                if let gw = c.gatewayIP { chip(gw, symbol: "arrow.triangle.branch") }
                if let ext = externalIP { chip(ext, symbol: "globe") }
                ForEach(Array(c.dnsServers.prefix(2).enumerated()), id: \.offset) { _, dns in
                    chip(dns, symbol: "server.rack")
                }
            }
        } else {
            Text(Localized.string("연결 없음", "Not connected"))
                .font(TLFont.caption)
                .foregroundColor(TLPalette.danger)
        }
    }

    /// 고가 경로 · 저전력 모드 · 자동화 · 절약 모드 · 프로필
    @ViewBuilder
    private var flagsRow: some View {
        HStack(spacing: TLSpace.md) {
            if let c = connection, c.isExpensive {
                flagChip(Localized.expensivePath, color: TLPalette.upload, symbol: "dollarsign.circle")
            }
            if let c = connection, c.isConstrained {
                flagChip(Localized.constrainedPath, color: TLPalette.danger, symbol: "gauge.with.dots.needle.bottom.50percent")
            }
            if AutomationManager.shared.rules.contains(where: { $0.isEnabled }) {
                flagChip(Localized.automation, color: TLPalette.accent, symbol: "wand.and.stars")
            }
            if store.snapshot.hasProfile, let name = store.snapshot.profileName {
                flagChip(name, color: TLPalette.textSecondary, symbol: "person.crop.circle")
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(_ text: String, symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 8))
            Text(text).font(.system(size: 10, design: .monospaced)).monospacedDigit()
        }
        .foregroundColor(TLPalette.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(TLPalette.textBackground, in: Capsule())
    }

    private func flagChip(_ text: String, color: Color, symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(text).font(TLFont.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }

    static func typeText(_ c: ConnectionInfo) -> String {
        switch c.type {
        case .normalWiFi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .iOSPersonalHotspot: return "iOS"
        case .androidHotspot: return "Android"
        case .unknown: return "—"
        }
    }

    /// MAC 주소 — `NetworkMonitor.macAddress` 사용
    ///
    /// 주의: `macAddress(forInterface:)` 는 7자 이상 인터페이스명에서 `continue` 가
    /// `ptr = next` 를 건너뛰어 무한루프에 빠진다(감사 T-250, 미해결).
    /// 대시보드는 5초 타이머로 반복 호출하므로 여기서는 길이 가드로 방어한다.
    static func mac(interface: String?) -> String? {
        guard let interface, interface.count < 7 else { return nil }
        return NetworkMonitor.shared.macAddress(forInterface: interface)
    }
}

// MARK: - 헬퍼 뷰

/// 자동 줄바꿈 칩 행
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += lineHeight + spacing; lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += lineHeight + spacing; lineHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - ⑤ CPU

/// ⑤ CPU — 큰값 + 게이지 + load + 코어바 + 스파크라인 + Top3
struct DashboardCpuCard: View {
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @ObservedObject private var history = MetricsHistory.shared

    private var load: SystemLoad? { trafficMonitor.systemLoad }
    private var top3: [(name: String, res: ProcessResource)] {
        trafficMonitor.allResources
            .map { (name: $0.key, res: $0.value) }
            .filter { $0.res.cpuPercent != nil }
            .sorted { ($0.res.cpuPercent ?? -1) > ($1.res.cpuPercent ?? -1) }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        MetricCard(title: DashboardCard.cpu.title, fillsRow: true) {
            VStack(alignment: .leading, spacing: TLSpace.sm) {
                if let l1 = load?.load1 {
                    Text(String(format: "load %.2f", l1))
                        .font(TLFont.mediumMono)
                        .foregroundColor(TLPalette.textSecondary)
                }
                if let cpu = load?.cpuTotalPercent {
                    TLGaugeBar(value: cpu, tint: TLPalette.cpuHeat(cpu))
                }
                let cores = load?.perCore ?? []
                if !cores.isEmpty {
                    TLCoreBars(percents: cores, tint: TLPalette.download)
                }
                TLSparkline(points: history.cpuHistory, color: TLPalette.download)
                resourceRows
            }
        }
    }

    @ViewBuilder
    private var resourceRows: some View {
        if !top3.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(top3, id: \.name) { e in
                    HStack(spacing: TLSpace.sm) {
                        Text(e.name)
                            .font(TLFont.medium)
                            .foregroundColor(TLPalette.textPrimary.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text(SystemResourceMonitor.formatCPU(e.res.cpuPercent))
                            .font(TLFont.mediumMono)
                            .foregroundColor(TLPalette.cpuHeat(e.res.cpuPercent))
                    }
                }
            }
        }
    }
}

// MARK: - ⑥ GPU

/// ⑥ GPU — 큰값 + 게이지 + 스파크라인
struct DashboardGpuCard: View {
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @ObservedObject private var history = MetricsHistory.shared

    private var gpu: Double? { trafficMonitor.systemLoad?.gpuPercent }
    private var available: Bool { gpu != nil || !history.gpuHistory.isEmpty }

    var body: some View {
        MetricCard(
            title: DashboardCard.gpu.title,
            trailing: available ? SystemResourceMonitor.formatCPU(gpu) : nil,
            fillsRow: true
        ) {
            VStack(alignment: .leading, spacing: TLSpace.sm) {
                if available {
                    if let gpu {
                        TLGaugeBar(value: gpu, tint: TLPalette.download)
                    }
                    TLSparkline(points: history.gpuHistory, color: TLPalette.download)
                } else {
                    // 미지원/미측정을 0으로 그리지 않는다 (RelayConsole 원칙 5)
                    Text(Localized.string("미지원", "Not supported"))
                        .font(TLFont.caption)
                        .foregroundColor(TLPalette.copyHint)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - ⑦ RAM

/// ⑦ RAM — used/total + 게이지(압력색) + 스파크라인 + Top3
struct DashboardMemoryCard: View {
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @ObservedObject private var history = MetricsHistory.shared

    private var used: Int64 { trafficMonitor.systemLoad?.memUsedBytes ?? -1 }
    private var total: Int64 { trafficMonitor.systemLoad?.memTotalBytes ?? -1 }
    private var ratio: Double { (used >= 0 && total > 0) ? Double(used) / Double(total) * 100 : 0 }

    private var top3: [(name: String, res: ProcessResource)] {
        trafficMonitor.allResources
            .map { (name: $0.key, res: $0.value) }
            .sorted { $0.res.rssBytes > $1.res.rssBytes }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        MetricCard(
            title: DashboardCard.memory.title,
            trailing: used >= 0 ? SystemResourceMonitor.formatMemUsedTotal(used: used, total: total) : nil,
            fillsRow: true
        ) {
            VStack(alignment: .leading, spacing: TLSpace.sm) {
                if used >= 0, total > 0 {
                    TLGaugeBar(value: ratio, tint: Self.memTint(ratio))
                }
                TLSparkline(points: history.memHistory, color: TLPalette.download)
                if !top3.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(top3, id: \.name) { e in
                            HStack(spacing: TLSpace.sm) {
                                Text(e.name)
                                    .font(TLFont.medium)
                                    .foregroundColor(TLPalette.textPrimary.opacity(0.85))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 4)
                                Text(SystemResourceMonitor.formatMemory(e.res.rssBytes))
                                    .font(TLFont.mediumMono)
                                    .foregroundColor(TLPalette.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 메모리 압력 색 (80% 이상 경고)
    static func memTint(_ ratio: Double) -> Color {
        ratio >= 85 ? TLPalette.danger : (ratio >= 65 ? TLPalette.upload : TLPalette.download)
    }
}

// MARK: - ⑧ 프로세스 리스트

/// ⑧ 프로세스 리스트 — CPU 순위 + 네트워크 + RAM, 스크롤, 더보기
struct DashboardProcessCard: View {
    @ObservedObject private var trafficMonitor = TrafficMonitor.shared
    @ObservedObject private var history = MetricsHistory.shared

    var onShowProcesses: (() -> Void)?

    /// 프로세스명 하나에 CPU·RAM·네트워크를 합친 행 모델
    struct Row: Identifiable {
        let id: String
        let name: String
        let cpu: Double?
        let rss: Int64
        var net: Int64
    }

    private static let limit = 12

    private var rows: [Row] {
        var map: [String: Row] = [:]
        for (name, res) in trafficMonitor.allResources {
            guard !SystemProcesses.set.contains(name) else { continue }
            map[name] = Row(id: name, name: name, cpu: res.cpuPercent, rss: res.rssBytes, net: 0)
        }
        for app in trafficMonitor.apps {
            let net = app.bytesIn + app.bytesOut
            guard net > 0 else { continue }
            if var existing = map[app.processName] {
                existing.net = net
                map[app.processName] = existing
            } else {
                map[app.processName] = Row(id: app.processName, name: app.processName, cpu: nil, rss: 0, net: net)
            }
        }
        let list = map.values.sorted { a, b in
            Self.score(a) > Self.score(b)
        }
        return Array(list.prefix(Self.limit))
    }

    /// 정렬 점수 — CPU 우세, 그다음 RAM, 그다음 네트워크 (1코어=100% 기준 정규화)
    private static func score(_ r: Row) -> Double {
        (r.cpu ?? 0) + Double(r.rss) / (1024 * 1024 * 1024) * 20 + Double(r.net) / (10 * 1024 * 1024) * 5
    }

    private var windowSeconds: Double { max(SettingsManager.shared.trafficMonitorInterval, 1) }
    private var memTotal: Int64 { trafficMonitor.systemLoad?.memTotalBytes ?? 0 }

    var body: some View {
        MetricCard(
            title: DashboardCard.process.title,
            fillsRow: true
        ) {
            VStack(alignment: .leading, spacing: 3) {
                header
                if rows.isEmpty {
                    Text(Localized.trafficCollecting)
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.copyHint)
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(rows) { r in row(r) }
                        }
                    }
                    .frame(maxHeight: 190)
                    Spacer(minLength: 0)
                }
                if onShowProcesses != nil {
                    Button { onShowProcesses?() } label: {
                        HStack(spacing: 2) {
                            Text(Localized.more).font(TLFont.caption2)
                            Image(systemName: "chevron.right").font(TLFont.badge)
                        }
                        .foregroundColor(TLPalette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: TLSpace.sm) {
            Text(Localized.string("프로세스", "Process"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU").frame(width: 46, alignment: .trailing)
            Text("MEM").frame(width: 56, alignment: .trailing)
            Text("NET").frame(width: 62, alignment: .trailing)
        }
        .font(TLFont.badge)
        .foregroundColor(TLPalette.copyHint)
    }

    private func row(_ r: Row) -> some View {
        HStack(spacing: TLSpace.sm) {
            Text(r.name)
                .font(TLFont.medium)
                .foregroundColor(TLPalette.textPrimary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(SystemResourceMonitor.formatCPU(r.cpu))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.cpuHeat(r.cpu))
                .frame(width: 46, alignment: .trailing)
            Text(memPercent(r.rss))
                .font(TLFont.mediumMono)
                .foregroundColor(DashboardMemoryCard.memTint(memPercentValue(r.rss)))
                .frame(width: 56, alignment: .trailing)
            Text(netRate(r.net))
                .font(TLFont.mediumMono)
                .foregroundColor(r.net > 0 ? TLPalette.download : TLPalette.copyHint)
                .frame(width: 62, alignment: .trailing)
        }
    }

    private func memPercentValue(_ rss: Int64) -> Double {
        guard memTotal > 0 else { return 0 }
        return Double(rss) / Double(memTotal) * 100
    }

    private func memPercent(_ rss: Int64) -> String {
        guard memTotal > 0, rss > 0 else { return "—" }
        return String(format: "%.1f%%", memPercentValue(rss))
    }

    private func netRate(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let perSec = Double(bytes) / windowSeconds
        if perSec >= 1_000_000 { return String(format: "%.1fM", perSec / 1_000_000) }
        if perSec >= 1_000 { return String(format: "%.0fK", perSec / 1_000) }
        return String(format: "%.0fB", perSec)
    }
}

// MARK: - ④ 오늘 사용 패턴

/// ④ 오늘 사용 패턴 — 24시 바 + 최근 8일 스파크라인
/// `DashboardStore`(60초) 만 관찰
struct DashboardPatternCard: View {
    @ObservedObject private var store = DashboardStore.shared

    private var s: DashboardStore.Snapshot { store.snapshot }

    var body: some View {
        MetricCard(title: DashboardCard.pattern.title, fillsRow: true) {
            VStack(alignment: .leading, spacing: TLSpace.sm) {
                hourlyBars
                Text(Localized.string("0시", "00") + " – " + Localized.string("23시", "23"))
                    .font(TLFont.badge)
                    .foregroundColor(TLPalette.copyHint)
                Divider().overlay(TLPalette.separator.opacity(0.35))
                dailySpark
            }
        }
    }

    /// 24시 막대 — 데이터가 있는 구간만 칠한다 (0으로 채우지 않는다)
    @ViewBuilder
    private var hourlyBars: some View {
        let totals = s.hourlyTotals
        let sum = s.hourlySum
        if sum > 0 {
            GeometryReader { geo in
                let count = max(totals.count, 1)
                let slot = geo.size.width / CGFloat(count)
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(totals.enumerated()), id: \.offset) { hour, v in
                        let ratio = Double(v) / Double(sum)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(v > 0 ? TLPalette.download.opacity(0.35 + 0.65 * ratio) : TLPalette.separator.opacity(0.25))
                            .frame(width: max(slot - 1, 1), height: max(geo.size.height * ratio, v > 0 ? 2 : 1))
                    }
                }
            }
            .frame(height: 46)
        } else {
            Text(Localized.noUsageData)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.copyHint)
                .frame(height: 46, alignment: .center)
        }
    }

    @ViewBuilder
    private var dailySpark: some View {
        let days = s.dailyTotals
        if days.count >= 2 {
            VStack(alignment: .leading, spacing: 2) {
                Text(Localized.string("최근 8일", "Last 8 days"))
                    .font(TLFont.badge)
                    .foregroundColor(TLPalette.copyHint)
                TLSparkline(points: days.map(Double.init), color: TLPalette.accent)
                HStack {
                    Text(DashboardView.bytes(days.reduce(0, +)))
                    Spacer()
                    Text(String(format: Localized.string("일평균 %@", "avg %@"), DashboardView.bytes(days.reduce(0, +) / Int64(days.count))))
                }
                .font(TLFont.badge)
                .foregroundColor(TLPalette.textSecondary)
                .monospacedDigit()
            }
        } else {
            Text(Localized.noUsageData)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.copyHint)
        }
    }
}

// MARK: - ⑨ 눈여겨볼 점 (전폭 · 목록형)

/// ⑨ 눈여겨볼 점 — 인사이트 6종을 전폭으로.
///
/// v0.39 이전엔 인사이트가 **리포트 차트 탭에 진입해야만** 계산됐다
/// (`UsageReportView` 의 `viewMode == .chart` 조건 — 현재는 `compute` 안에 있다).
/// 이제 `DashboardStore` 가 60초 주기로 상시 계산하므로 대시보드에서 바로 보인다.
///
/// 표시 규칙(아이콘·색·히어로·문구)은 `InsightPresenter` 를 리포트와 공유한다.
struct DashboardInsightCard: View {
    @ObservedObject private var store = DashboardStore.shared

    var onShowAppTraffic: (() -> Void)?
    var onOpenDiagnostics: (() -> Void)?

    private var items: [InsightItem] { store.snapshot.insights }

    var body: some View {
        MetricCard(
            title: DashboardCard.insight.title,
            trailing: items.isEmpty ? nil : "\(items.count)"
        ) {
            if items.isEmpty {
                // 특이사항 없음 — success 도트 + 문구 (0 으로 오해하지 않게)
                HStack(spacing: TLSpace.sm) {
                    Circle().fill(TLPalette.success).frame(width: 8, height: 8)
                    Text(Localized.insightNone)
                        .font(TLFont.caption)
                        .foregroundColor(TLPalette.textSecondary)
                    Spacer(minLength: 0)
                }
            } else {
                // 2열 그리드 — 카드가 6개까지 늘어날 수 있어 세로로 길어지지 않게
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: TLSpace.md, alignment: .top),
                              GridItem(.flexible(), spacing: TLSpace.md, alignment: .top)],
                    spacing: TLSpace.sm
                ) {
                    ForEach(items) { insight in
                        item(insight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func item(_ insight: InsightItem) -> some View {
        let actionable = InsightPresenter.isActionable(insight.kind)
        let color = InsightPresenter.color(for: insight.kind)

        let row = HStack(alignment: .top, spacing: TLSpace.md) {
            Image(systemName: InsightPresenter.icon(for: insight.kind))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(InsightPresenter.hero(for: insight))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(color)
                        .lineLimit(1)
                    Text(InsightPresenter.title(for: insight))
                        .font(TLFont.smallBold)
                        .foregroundColor(TLPalette.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(InsightPresenter.body(for: insight))
                    .font(TLFont.caption2)
                    .foregroundColor(TLPalette.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLPalette.textBackground.opacity(0.5), in: RoundedRectangle(cornerRadius: TLRound.small, style: .continuous))

        if actionable {
            Button {
                switch insight.kind {
                case .topOffender: onShowAppTraffic?()
                case .ipChurn: onOpenDiagnostics?()
                default: break
                }
            } label: { row }
            .buttonStyle(.plain)
            .help(Localized.more)
        } else {
            row
        }
    }
}
