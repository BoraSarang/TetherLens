import SwiftUI
import Charts
import UniformTypeIdentifiers

struct UsageReportView: View {
    @State private var profiles: [Profile] = []
    @State private var selectedProfileId: UUID?
    @State private var selectedPeriod: Period = .week
    @State private var dailyUsage: [ProfileManager.DailyUsage] = []
    @State private var monthlyUsage: [ProfileManager.MonthlyUsage] = []
    @State private var hourlyUsage: [ProfileManager.HourlyUsage] = []
    @State private var sessions: [Session] = []
    @State private var dailySessionSummary: [ProfileManager.DailySessionSummary] = []
    @State private var monthlySessionSummary: [ProfileManager.MonthlySessionSummary] = []
    @State private var viewMode: ViewMode = .chart
    @State private var appTrafficData: [(processName: String, uploadBytes: Int64, downloadBytes: Int64)] = []
    @State private var expandedSection: AppTrafficSection = .user
    @State private var sortOrder: TrafficSortOrder = .total
    @State private var previousPeriodTotal: Int64 = 0
    @State private var topHotspot: (name: String, total: Int64)?
    @State private var topApps: [(name: String, total: Int64)] = []

    enum TrafficSortOrder: CaseIterable {
        case total, upload, download
        var localized: String {
            switch self {
            case .total: return Localized.sortTotal
            case .upload: return Localized.sortUpload
            case .download: return Localized.sortDownload
            }
        }
    }

    enum AppTrafficSection {
        case user
        case system
    }

    let onClose: () -> Void
    let preselectedProfileId: UUID?

    enum ExportFormat {
        case csv, json, markdown
    }

    init(onClose: @escaping () -> Void, preselectedProfileId: UUID? = nil) {
        self.onClose = onClose
        self.preselectedProfileId = preselectedProfileId
    }

    private let allProfilesId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static let ReportAllProfilesId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    enum Period: CaseIterable {
        case day, week, month, halfYear, year
        var localized: String {
            switch self {
            case .day: return Localized.day
            case .week: return Localized.week
            case .month: return Localized.month
            case .halfYear: return Localized.halfYear
            case .year: return Localized.year
            }
        }

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .halfYear: return 180
            case .year: return 365
            }
        }

        var isLongPeriod: Bool { days > 30 }

        var months: Int {
            switch self {
            case .halfYear: return 6
            case .year: return 12
            default: return 0
            }
        }
    }

    enum ViewMode: CaseIterable {
        case chart, detail, session, heatmap, appTraffic, report
        var localized: String {
            switch self {
            case .chart: return Localized.chart
            case .detail: return Localized.detail
            case .session: return Localized.sessionTab
            case .heatmap: return Localized.heatmapTitle
            case .appTraffic: return Localized.appTrafficTab
            case .report: return Localized.reportTab
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Localized.usageReportTitle)
                    .font(TLFont.headline)
                    .padding(.leading, TLSpace.xxl)
                Spacer()
                Menu {
                    Button(Localized.exportCSV) { exportData(format: .csv) }
                    Button(Localized.exportJSON) { exportData(format: .json) }
                    Button(Localized.exportMarkdown) { exportData(format: .markdown) }
                } label: {
                    Label(Localized.export, systemImage: "square.and.arrow.up")
                        .font(TLFont.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(.trailing, TLSpace.xxl)
            }
            .padding(.top, TLSpace.xxl)
            .padding(.bottom, TLSpace.md)

            Divider()

            HStack(spacing: 0) {
                sidebar
                Divider()
                rightPanel
            }
        }
        .frame(width: TLSize.reportWindow.w, height: TLSize.reportWindow.h)
        .onAppear {
            profiles = ProfileManager.shared.getAllProfiles()
            selectedProfileId = preselectedProfileId ?? allProfilesId
            loadData()
        }
        .onChange(of: selectedProfileId) { _, _ in loadData() }
        .onChange(of: selectedPeriod) { _, _ in loadData() }
        .onChange(of: viewMode) { _, _ in loadData() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    viewMode = mode
                } label: {
                    Text(mode.localized)
                        .font(TLFont.subheadline)
                        .foregroundColor(viewMode == mode ? TLPalette.accent : TLPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, TLSpace.xl)
                        .padding(.vertical, TLSpace.lg)
                        .background(viewMode == mode ? TLPalette.accent.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(width: TLSize.sidebarWidth)
        .padding(.vertical, TLSpace.md)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: TLSpace.md) {
            HStack(spacing: TLSpace.md) {
                Picker("", selection: $selectedProfileId) {
                    Text(Localized.allProfiles).tag(allProfilesId as UUID?)
                    ForEach(profiles) { profile in
                        if profile.isHotspot {
                            Text("\(profile.name) (\(Localized.hotspot))").tag(profile.id as UUID?)
                        } else {
                            Text(profile.name).tag(profile.id as UUID?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .frame(width: TLSize.pickerWidth)

                Picker("", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.localized).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, TLSpace.xl)
            .padding(.top, TLSpace.md)

            if !dailyUsage.isEmpty {
                insightCards
            }

            Divider()
                .padding(.horizontal, TLSpace.xl)

            contentBody

            HStack {
                HStack(spacing: TLSpace.md) {
                    Text(Localized.upload)
                        .font(TLFont.caption.bold())
                        .foregroundColor(TLPalette.upload)
                    Text(Localized.download)
                        .font(TLFont.caption.bold())
                        .foregroundColor(TLPalette.download)
                }
                Spacer()
                Button(Localized.close, action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, TLSpace.xl)
            .padding(.bottom, TLSpace.xl)
        }
    }

    // MARK: - Insight Cards

    private var insightCards: some View {
        let columns = [
            GridItem(.flexible(), spacing: TLSpace.md),
            GridItem(.flexible(), spacing: TLSpace.md),
            GridItem(.flexible(), spacing: TLSpace.md)
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: TLSpace.md) {
            insightCard(
                title: Localized.totalUsage,
                value: totalBytes.formattedBytes,
                subtitle: "\(Localized.dailyAverage) \(Int64(totalBytes / max(Int64(dailyUsage.count), 1)).formattedBytes)",
                color: TLPalette.textPrimary
            )
            insightCard(
                title: Localized.vsPreviousPeriod,
                value: previousPeriodText,
                subtitle: "\(Localized.prevPeriod) \(previousPeriodTotal.formattedBytes)",
                color: previousPeriodColor
            )
            insightCard(
                title: Localized.topUsageDay,
                value: topUsageDayText,
                subtitle: topUsageDay?.total.formattedBytes ?? Localized.noUsageData,
                color: TLPalette.accent
            )
            insightCard(
                title: Localized.topHotspot,
                value: topHotspot?.name ?? Localized.noConnection,
                subtitle: topHotspot.map { $0.total.formattedBytes } ?? "",
                color: TLPalette.upload
            )
            if let q = quotaUsagePct {
                insightCard(
                    title: Localized.quotaUsage,
                    value: String(format: "%.1f%%", q),
                    subtitle: expectedExhaustionDays.map { Localized.expectedExhaustion + " \($0)일" } ?? "",
                    color: q >= 90 ? TLPalette.danger : (q >= 60 ? TLPalette.upload : TLPalette.success)
                )
            }
            insightCard(
                title: Localized.topApps,
                value: topApps.isEmpty ? Localized.noUsageData : topApps.map { $0.name }.joined(separator: " · "),
                subtitle: topApps.isEmpty ? "" : topApps.map { $0.total.formattedBytes }.joined(separator: " · "),
                color: TLPalette.download
            )
        }
        .padding(.horizontal, TLSpace.xl)
    }

    private func insightCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(TLFont.callout.monospacedDigit().bold())
                .foregroundColor(color)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(subtitle)
                .font(TLFont.caption2)
                .foregroundColor(TLPalette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, TLSpace.sm)
        .padding(.horizontal, TLSpace.md)
        .background(TLPalette.textBackground.opacity(0.5))
        .cornerRadius(TLRound.small)
    }

    private var previousPeriodText: String {
        guard let pct = previousPeriodPct else { return "—" }
        return "\(pct >= 0 ? "▲" : "▼") \(String(format: "%.1f%%", abs(pct)))"
    }

    private var previousPeriodColor: Color {
        guard let pct = previousPeriodPct else { return TLPalette.textSecondary }
        return pct > 0 ? TLPalette.upload : TLPalette.success
    }

    private var topUsageDayText: String {
        guard let day = topUsageDay else { return "—" }
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("M/d")
        return f.string(from: day.date)
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        switch viewMode {
        case .chart:
            chartView
        case .detail:
            detailView
        case .session:
            sessionView
        case .appTraffic:
            appTrafficView
        case .heatmap:
            HeatmapView(sessions: sessions)
        case .report:
            ReportView(
                profiles: profiles,
                selectedProfileId: selectedProfileId,
                selectedPeriod: selectedPeriod
            )
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        let isDay = selectedPeriod.days == 1
        let isWeekly = selectedPeriod.days == 7
        let isLong = selectedPeriod.isLongPeriod
        let source = chartDataSource
        if source.isEmpty {
            Spacer()
            Text(Localized.noUsageData)
                .foregroundColor(TLPalette.textSecondary)
            Spacer()
        } else {
            let peakBar = source.map { max($0.upload, $0.download) }.max() ?? 1
            let peakCumulative = source.enumerated().map { cumulativeTotal(source, upTo: $0.offset) }.max() ?? peakBar
            let peakQuota = quotaRuleMarkBytes ?? 0
            let yTop = max(peakBar * 2, peakCumulative, peakQuota) * 11 / 10
            let yDomain: ClosedRange<Int64> = 0 ... max(yTop, 1)
            Chart {
                ForEach(Array(source.enumerated()), id: \.element.id) { index, usage in
                    if isDay {
                        BarMark(
                            x: .value("Hour", usage.hour),
                            y: .value("Upload", usage.upload)
                        )
                        .foregroundStyle(TLPalette.upload)
                        .annotation(position: .bottom, alignment: .center) {
                            Text(usage.hourLabel)
                                .font(TLFont.caption2)
                                .foregroundColor(TLPalette.textSecondary)
                        }
                        BarMark(
                            x: .value("Hour", usage.hour),
                            y: .value("Download", usage.download)
                        )
                        .foregroundStyle(TLPalette.download)
                    } else if isWeekly {
                        BarMark(
                            x: .value("Weekday", usage.hour),
                            y: .value("Upload", usage.upload)
                        )
                        .foregroundStyle(TLPalette.upload)
                        .annotation(position: .bottom, alignment: .center) {
                            Text(usage.weekdayLabel)
                                .font(TLFont.caption2)
                                .foregroundColor(TLPalette.textSecondary)
                        }
                        BarMark(
                            x: .value("Weekday", usage.hour),
                            y: .value("Download", usage.download)
                        )
                        .foregroundStyle(TLPalette.download)
                    } else {
                        BarMark(
                            x: .value("Date", usage.date ?? Date.distantPast, unit: isLong ? .month : .day),
                            y: .value("Upload", usage.upload)
                        )
                        .foregroundStyle(TLPalette.upload)
                        .annotation(position: .bottom, alignment: .center) {
                            Text(usage.dateLabel)
                                .font(TLFont.caption2)
                                .foregroundColor(TLPalette.textSecondary)
                        }
                        BarMark(
                            x: .value("Date", usage.date ?? Date.distantPast, unit: isLong ? .month : .day),
                            y: .value("Download", usage.download)
                        )
                        .foregroundStyle(TLPalette.download)
                    }
                    if isDay {
                        LineMark(
                            x: .value("Hour", usage.hour),
                            y: .value("Cumulative", cumulativeTotal(source, upTo: index))
                        )
                        .foregroundStyle(TLPalette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    } else if isWeekly {
                        LineMark(
                            x: .value("Weekday", usage.hour),
                            y: .value("Cumulative", cumulativeTotal(source, upTo: index))
                        )
                        .foregroundStyle(TLPalette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    } else {
                        LineMark(
                            x: .value("Date", usage.date ?? Date.distantPast, unit: isLong ? .month : .day),
                            y: .value("Cumulative", cumulativeTotal(source, upTo: index))
                        )
                        .foregroundStyle(TLPalette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                if let quotaLine = quotaRuleMarkBytes {
                    RuleMark(
                        y: .value("Quota", quotaLine)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(TLPalette.danger.opacity(0.6))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(Localized.quotaRuleLabel)
                            .font(TLFont.small)
                            .foregroundColor(TLPalette.danger)
                    }
                }
            }
            .chartForegroundStyleScale([
                Localized.uploadShort: TLPalette.upload,
                Localized.downloadShort: TLPalette.download
            ])
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            Text(formatTotalBytes(Int64(bytes)))
                                .font(TLFont.small)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(.horizontal, TLSpace.xl)
            .frame(height: 280)
            Spacer()
        }
    }

    /// 기간별 세분화 데이터 소스.
    private struct ChartEntry: Identifiable {
        let id: String
        let date: Date?
        let hour: Int
        let upload: Int64
        let download: Int64
        let isLongPeriod: Bool

        var total: Int64 { upload + download }

        var hourLabel: String {
            String(format: "%02d", hour)
        }

        var weekdayLabel: String {
            let symbols = Calendar.current.shortStandaloneWeekdaySymbols
            guard symbols.indices.contains(hour + 1) else { return "" }
            return symbols[hour + 1]
        }

        var dateLabel: String {
            guard let date else { return "" }
            if isLongPeriod {
                let f = DateFormatter()
                f.dateFormat = "M'월'"
                return f.string(from: date)
            }
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return f.string(from: date)
        }
    }

    private var chartDataSource: [ChartEntry] {
        if selectedPeriod.days == 1 {
            return hourlyChartData
        } else if selectedPeriod.days == 7 {
            return weeklyChartData
        } else if selectedPeriod.isLongPeriod {
            return longChartData
        } else {
            return monthlyChartData
        }
    }

    /// day(1일) — 시간대(0~23)별, 0인 시간은 빈 값으로 채움
    private var hourlyChartData: [ChartEntry] {
        var byHour = Dictionary(uniqueKeysWithValues: hourlyUsage.map { ($0.hour, $0) })
        return (0..<24).map { hour in
            if let u = byHour[hour] {
                return ChartEntry(id: "\(hour)", date: nil, hour: hour, upload: u.upload, download: u.download, isLongPeriod: false)
            } else {
                return ChartEntry(id: "\(hour)", date: nil, hour: hour, upload: 0, download: 0, isLongPeriod: false)
            }
        }
    }

    /// month(30일) — 일별
    private var monthlyChartData: [ChartEntry] {
        dailyUsage.map { ChartEntry(id: $0.id, date: $0.date, hour: 0, upload: $0.upload, download: $0.download, isLongPeriod: false) }
    }

    /// halfYear(180일)/year(365일) — 월별
    private var longChartData: [ChartEntry] {
        monthlyUsage.map { ChartEntry(id: $0.id, date: $0.date, hour: 0, upload: $0.upload, download: $0.download, isLongPeriod: true) }
    }

    /// week(7일) — 요일별 합산 (0=일~6=토)
    private var weeklyChartData: [ChartEntry] {
        let cal = Calendar.current
        var weekdayTotals: [Int: (upload: Int64, download: Int64)] = [:]
        for u in dailyUsage {
            let wd = cal.component(.weekday, from: u.date) // 1=일...7=토
            let idx = wd - 1 // 0=일...6=토
            let cur = weekdayTotals[idx] ?? (0, 0)
            weekdayTotals[idx] = (cur.upload + u.upload, cur.download + u.download)
        }
        let dayStride: [Int] = [0, 1, 2, 3, 4, 5, 6]
        return dayStride.compactMap { idx in
            let t = weekdayTotals[idx] ?? (0, 0)
            return ChartEntry(id: "\(idx)", date: nil, hour: idx, upload: t.upload, download: t.download, isLongPeriod: false)
        }
    }

    /// 할당량 임계선 값(바이트). 전체 프로필 또는 할당량 미설정이면 nil.
    private var quotaRuleMarkBytes: Int64? {
        guard let pid = selectedProfileId, pid != allProfilesId,
              let profile = ProfileManager.shared.getProfile(id: pid),
              let quota = profile.quotaGB, quota > 0 else { return nil }
        return Int64(quota * 1_000_000_000)
    }

    private func cumulativeTotal(_ source: [ChartEntry], upTo index: Int) -> Int64 {
        source[0...index].reduce(0) { $0 + $1.total }
    }

    // MARK: - Detail

    private var detailView: some View {
        Group {
            let isLong = selectedPeriod.isLongPeriod
            let items = isLong ? monthlyUsage.map { DetailItem(id: $0.id, date: $0.date, upload: $0.upload, download: $0.download, total: $0.total, isMonthly: true) } : dailyUsage.map { DetailItem(id: $0.id, date: $0.date, upload: $0.upload, download: $0.download, total: $0.total, isMonthly: false) }
            if items.isEmpty {
            Spacer()
            Text(Localized.noUsageData)
                .foregroundColor(TLPalette.textSecondary)
            Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text(isLong ? Localized.monthLabel : Localized.date)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(width: TLSize.rowColWide, alignment: .leading)
                            Text(Localized.uploadShort)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.upload)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(Localized.downloadShort)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.download)
                                .frame(width: TLSize.rowColWide, alignment: .trailing)
                            Text(Localized.total)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(width: TLSize.rowColWide, alignment: .trailing)
                        }
                        .padding(.vertical, TLSpace.xs)
                        ForEach(items) { item in
                            Divider()
                            HStack(spacing: 0) {
                                if item.isMonthly {
                                    Text(item.date, format: .dateTime.month().year())
                                        .font(TLFont.caption)
                                        .frame(width: TLSize.rowColWide, alignment: .leading)
                                } else {
                                    Text(item.date, format: .dateTime.day().month())
                                        .font(TLFont.caption)
                                        .frame(width: TLSize.rowColWide, alignment: .leading)
                                }
                                Text(item.upload.formattedBytes)
                                    .font(TLFont.caption.monospacedDigit())
                                    .foregroundColor(TLPalette.upload)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(item.download.formattedBytes)
                                    .font(TLFont.caption.monospacedDigit())
                                    .foregroundColor(TLPalette.download)
                                    .frame(width: TLSize.rowColWide, alignment: .trailing)
                                Text(item.total.formattedBytes)
                                    .font(TLFont.caption.monospacedDigit().bold())
                                    .frame(width: TLSize.rowColWide, alignment: .trailing)
                            }
                            .padding(.vertical, TLSpace.xs)
                        }
                    }
                    .padding(.horizontal, TLSpace.xl)
                }
            }
        }
    }

    private struct DetailItem: Identifiable {
        let id: String
        let date: Date
        let upload: Int64
        let download: Int64
        let total: Int64
        let isMonthly: Bool
    }

    // MARK: - Session

    private var sessionView: some View {
        Group {
            if selectedPeriod.days == 1 {
                individualSessionView
            } else if selectedPeriod.isLongPeriod {
                monthlySessionSummaryView
            } else {
                dailySessionSummaryView
            }
        }
    }

    private var individualSessionView: some View {
        let name: String = {
            if let pid = selectedProfileId {
                if pid == allProfilesId { return Localized.allProfiles }
                return ProfileManager.shared.getProfile(id: pid)?.name ?? "-"
            }
            return "-"
        }()
        return SessionTimelineView(sessions: sessions, profileName: name)
    }

    private var dailySessionSummaryView: some View {
        Group {
            if dailySessionSummary.isEmpty {
                Spacer()
                Text(Localized.noSessionData)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text(Localized.date)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Localized.sessionCount)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(width: TLSize.rowColNarrow, alignment: .trailing)
                            Text(Localized.time)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(width: TLSize.rowColTime, alignment: .trailing)
                        }
                        .padding(.vertical, TLSpace.xs)
                        ForEach(dailySessionSummary) { item in
                            Divider()
                            HStack(spacing: 0) {
                                Text(item.date, format: .dateTime.day().month())
                                    .font(TLFont.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(item.sessionCount)")
                                    .font(TLFont.caption.monospacedDigit())
                                    .frame(width: TLSize.rowColNarrow, alignment: .trailing)
                                Text(formatDuration(item.totalDuration))
                                    .font(TLFont.caption.monospacedDigit())
                                    .frame(width: TLSize.rowColTime, alignment: .trailing)
                            }
                            .padding(.vertical, TLSpace.xs)
                        }
                    }
                    .padding(.horizontal, TLSpace.xl)
                }
            }
        }
    }

    private var monthlySessionSummaryView: some View {
        Group {
            if monthlySessionSummary.isEmpty {
                Spacer()
                Text(Localized.noSessionData)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text(Localized.monthLabel)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Localized.sessionCount)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(width: TLSize.rowColNarrow, alignment: .trailing)
                            Text(Localized.time)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(width: TLSize.rowColTime, alignment: .trailing)
                        }
                        .padding(.vertical, TLSpace.xs)
                        ForEach(monthlySessionSummary) { item in
                            Divider()
                            HStack(spacing: 0) {
                                Text(item.date, format: .dateTime.month().year())
                                    .font(TLFont.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(item.sessionCount)")
                                    .font(TLFont.caption.monospacedDigit())
                                    .frame(width: TLSize.rowColNarrow, alignment: .trailing)
                                Text(formatDuration(item.totalDuration))
                                    .font(TLFont.caption.monospacedDigit())
                                    .frame(width: TLSize.rowColTime, alignment: .trailing)
                            }
                            .padding(.vertical, TLSpace.xs)
                        }
                    }
                    .padding(.horizontal, TLSpace.xl)
                }
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - App Traffic

    private var appTrafficView: some View {
        Group {
            if appTrafficData.isEmpty {
                Spacer()
                Text(Localized.noTrafficData)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                let systemSet = SystemProcesses.set
                let sorted = appTrafficData.sorted { a, b in
                    switch sortOrder {
                    case .total: return a.uploadBytes + a.downloadBytes > b.uploadBytes + b.downloadBytes
                    case .upload: return a.uploadBytes > b.uploadBytes
                    case .download: return a.downloadBytes > b.downloadBytes
                    }
                }
                let userApps = sorted.filter { !systemSet.contains($0.processName) }
                let systemApps = sorted.filter { systemSet.contains($0.processName) }
                let totalUp = appTrafficData.reduce(0) { $0 + $1.uploadBytes }
                let totalDn = appTrafficData.reduce(0) { $0 + $1.downloadBytes }
                let userUp = userApps.reduce(0) { $0 + $1.uploadBytes }
                let userDn = userApps.reduce(0) { $0 + $1.downloadBytes }
                let sysUp = systemApps.reduce(0) { $0 + $1.uploadBytes }
                let sysDn = systemApps.reduce(0) { $0 + $1.downloadBytes }

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text(Localized.process)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Localized.upload)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.upload)
                                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
                            Text(Localized.download)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.download)
                                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
                        }
                        .frame(height: 20)

                        Divider()

                        summaryRow(label: Localized.totalSum, upload: totalUp, download: totalDn, isBold: true)
                        summaryRow(label: Localized.userSum, upload: userUp, download: userDn, isBold: true)
                        summaryRow(label: Localized.systemSum, upload: sysUp, download: sysDn, isBold: true)

                        Divider()
                            .padding(.vertical, TLSpace.xs)

                        HStack(spacing: 0) {
                            Spacer()
                            Picker(Localized.sortBy, selection: $sortOrder) {
                                ForEach(TrafficSortOrder.allCases, id: \.self) { order in
                                    Text(order.localized).tag(order)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.bottom, TLSpace.xs)
                    }
                    .padding(.horizontal, TLSpace.xl)

                    Divider()
                        .padding(.horizontal, TLSpace.xl)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                Button {
                                    withAnimation {
                                        expandedSection = expandedSection == .user ? .system : .user
                                        proxy.scrollTo("top", anchor: .top)
                                    }
                                } label: {
                                    HStack(spacing: TLSpace.xs) {
                                        Image(systemName: expandedSection == .user ? "chevron.down" : "chevron.right")
                                            .font(TLFont.badge)
                                            .foregroundColor(TLPalette.textSecondary)
                                        Text(Localized.userProcesses)
                                            .font(TLFont.smallBold)
                                            .foregroundColor(TLPalette.textSecondary)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, TLSpace.sm)
                                }
                                .buttonStyle(.plain)
                                .id("top")

                                if expandedSection == .user {
                                    ForEach(Array(userApps.prefix(10).enumerated()), id: \.element.processName) { _, item in
                                        Divider()
                                        appTrafficRow(item)
                                    }
                                }

                                Button {
                                    withAnimation {
                                        expandedSection = expandedSection == .system ? .user : .system
                                        proxy.scrollTo("top", anchor: .top)
                                    }
                                } label: {
                                    HStack(spacing: TLSpace.xs) {
                                        Image(systemName: expandedSection == .system ? "chevron.down" : "chevron.right")
                                            .font(TLFont.badge)
                                            .foregroundColor(TLPalette.textSecondary)
                                    Text(Localized.systemProcesses)
                                        .font(TLFont.smallBold)
                                        .foregroundColor(TLPalette.textSecondary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, TLSpace.sm)
                            }
                            .buttonStyle(.plain)

                            if expandedSection == .system {
                                ForEach(Array(systemApps.prefix(10).enumerated()), id: \.element.processName) { _, item in
                                        Divider()
                                        appTrafficRow(item)
                                    }
                                }
                            }
                            .padding(.horizontal, TLSpace.xl)
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(label: String, upload: Int64, download: Int64, isBold: Bool) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(TLFont.medium.weight(isBold ? .bold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTotalBytes(upload))
                .font(TLFont.mediumMono.weight(isBold ? .bold : .regular))
                .foregroundColor(TLPalette.upload)
                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
            Text(formatTotalBytes(download))
                .font(TLFont.mediumMono.weight(isBold ? .bold : .regular))
                .foregroundColor(TLPalette.download)
                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func appTrafficRow(_ item: (processName: String, uploadBytes: Int64, downloadBytes: Int64)) -> some View {
        HStack(spacing: 0) {
            Text(item.processName)
                .font(TLFont.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTotalBytes(item.uploadBytes))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.upload)
                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
            Text(formatTotalBytes(item.downloadBytes))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.download)
                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
        }
        .frame(height: 20)
    }

    // MARK: - Helpers

    private func loadData() {
        guard let pid = selectedProfileId else {
            dailyUsage = []
            monthlyUsage = []
            sessions = []
            dailySessionSummary = []
            monthlySessionSummary = []
            previousPeriodTotal = 0
            topHotspot = nil
            topApps = []
            return
        }
        let loadAllSessions = viewMode == .heatmap || (viewMode == .session && selectedPeriod.days == 1)
        let loadAppTraffic = viewMode == .appTraffic
        if pid == allProfilesId {
            var allUsage: [String: ProfileManager.DailyUsage] = [:]
            var allMonthly: [String: ProfileManager.MonthlyUsage] = [:]
            var allSessions: [Session] = []
            var allDailySess: [String: ProfileManager.DailySessionSummary] = [:]
            var allMonthlySess: [String: ProfileManager.MonthlySessionSummary] = [:]
            for profile in profiles {
                let usage = ProfileManager.shared.getDailyUsage(profileId: profile.id, days: selectedPeriod.days)
                for u in usage {
                    let existing = allUsage[u.id, default: ProfileManager.DailyUsage(id: u.id, date: u.date, upload: 0, download: 0)]
                    allUsage[u.id] = ProfileManager.DailyUsage(id: u.id, date: u.date, upload: existing.upload + u.upload, download: existing.download + u.download)
                }
                if loadAllSessions {
                    allSessions.append(contentsOf: ProfileManager.shared.getSessions(profileId: profile.id, days: selectedPeriod.days))
                }
                if selectedPeriod.isLongPeriod {
                    let months = selectedPeriod.months
                    let mu = ProfileManager.shared.getMonthlyUsage(profileId: profile.id, months: months)
                    for u in mu {
                        let existing = allMonthly[u.id, default: ProfileManager.MonthlyUsage(id: u.id, date: u.date, upload: 0, download: 0)]
                        allMonthly[u.id] = ProfileManager.MonthlyUsage(id: u.id, date: u.date, upload: existing.upload + u.upload, download: existing.download + u.download)
                    }
                    let ms = ProfileManager.shared.getMonthlySessionSummary(profileId: profile.id, months: months)
                    for s in ms {
                        let existing = allMonthlySess[s.id, default: ProfileManager.MonthlySessionSummary(id: s.id, date: s.date, sessionCount: 0, totalDuration: 0)]
                        allMonthlySess[s.id] = ProfileManager.MonthlySessionSummary(id: s.id, date: s.date, sessionCount: existing.sessionCount + s.sessionCount, totalDuration: existing.totalDuration + s.totalDuration)
                    }
                } else if selectedPeriod.days > 1 {
                    let ds = ProfileManager.shared.getDailySessionSummary(profileId: profile.id, days: selectedPeriod.days)
                    for s in ds {
                        let existing = allDailySess[s.id, default: ProfileManager.DailySessionSummary(id: s.id, date: s.date, sessionCount: 0, totalDuration: 0)]
                        allDailySess[s.id] = ProfileManager.DailySessionSummary(id: s.id, date: s.date, sessionCount: existing.sessionCount + s.sessionCount, totalDuration: existing.totalDuration + s.totalDuration)
                    }
                }
            }
            dailyUsage = allUsage.values.sorted { $0.date < $1.date }
            monthlyUsage = allMonthly.values.sorted { $0.date < $1.date }
            if selectedPeriod.days == 1 {
                var allHourly: [Int: ProfileManager.HourlyUsage] = [:]
                for profile in profiles {
                    for h in ProfileManager.shared.getHourlyUsage(profileId: profile.id, days: 1) {
                        let existing = allHourly[h.hour, default: ProfileManager.HourlyUsage(id: h.hour, hour: h.hour, upload: 0, download: 0)]
                        allHourly[h.hour] = ProfileManager.HourlyUsage(id: h.hour, hour: h.hour, upload: existing.upload + h.upload, download: existing.download + h.download)
                    }
                }
                hourlyUsage = allHourly.values.sorted { $0.hour < $1.hour }
            } else {
                hourlyUsage = []
            }
            sessions = allSessions.sorted { $0.startTime > $1.startTime }
            dailySessionSummary = allDailySess.values.sorted { $0.date < $1.date }
            monthlySessionSummary = allMonthlySess.values.sorted { $0.date < $1.date }
            appTrafficData = loadAppTraffic ? ProfileManager.shared.getAppTrafficLogs(days: selectedPeriod.days) : []
            loadInsights()
            return
        }
        dailyUsage = ProfileManager.shared.getDailyUsage(profileId: pid, days: selectedPeriod.days)
        if selectedPeriod.isLongPeriod {
            monthlyUsage = ProfileManager.shared.getMonthlyUsage(profileId: pid, months: selectedPeriod.months)
            monthlySessionSummary = ProfileManager.shared.getMonthlySessionSummary(profileId: pid, months: selectedPeriod.months)
            sessions = loadAllSessions ? ProfileManager.shared.getSessions(profileId: pid, days: selectedPeriod.days) : []
            dailySessionSummary = []
        } else if selectedPeriod.days > 1 {
            sessions = loadAllSessions ? ProfileManager.shared.getSessions(profileId: pid, days: selectedPeriod.days) : []
            dailySessionSummary = ProfileManager.shared.getDailySessionSummary(profileId: pid, days: selectedPeriod.days)
            monthlySessionSummary = []
        } else {
            sessions = ProfileManager.shared.getSessions(profileId: pid, days: selectedPeriod.days)
            dailySessionSummary = []
            monthlySessionSummary = []
        }
        hourlyUsage = selectedPeriod.days == 1 ? ProfileManager.shared.getHourlyUsage(profileId: pid, days: 1) : []
        appTrafficData = loadAppTraffic ? ProfileManager.shared.getAppTrafficLogs(days: selectedPeriod.days) : []
        loadInsights()
    }

    // MARK: - Insights

    private func loadInsights() {
        let pid = selectedProfileId
        let days = selectedPeriod.days
        let cal = Calendar.current
        let now = Date()
        let prevTo = cal.date(byAdding: .day, value: -days, to: now)!
        let prevFrom = cal.date(byAdding: .day, value: -days * 2, to: now)!
        let effectivePid = pid == allProfilesId ? nil : pid
        previousPeriodTotal = ProfileManager.shared.getUsageTotal(profileId: effectivePid, from: prevFrom, to: prevTo)
        topApps = Array(ProfileManager.shared.getAppTrafficLogs(days: days)
            .filter { !SystemProcesses.set.contains($0.processName) }
            .sorted { $0.uploadBytes + $0.downloadBytes > $1.uploadBytes + $1.downloadBytes }
            .prefix(3)
            .map { ($0.processName, $0.uploadBytes + $0.downloadBytes) })
        if pid == allProfilesId {
            var best: (name: String, total: Int64)?
            for profile in profiles {
                let total = ProfileManager.shared.getDailyUsage(profileId: profile.id, days: days)
                    .reduce(0) { $0 + $1.total }
                if total > (best?.total ?? 0) {
                    best = (profile.name, total)
                }
            }
            topHotspot = best
        } else if let p = profiles.first(where: { $0.id == pid }) {
            topHotspot = (p.name, dailyUsage.reduce(0) { $0 + $1.total })
        } else {
            topHotspot = nil
        }
    }

    private var totalBytes: Int64 {
        dailyUsage.reduce(0) { $0 + $1.total }
    }

    private var topUsageDay: ProfileManager.DailyUsage? {
        dailyUsage.max { $0.total < $1.total }
    }

    private var previousPeriodPct: Double? {
        guard previousPeriodTotal > 0 else { return nil }
        return (Double(totalBytes) - Double(previousPeriodTotal)) / Double(previousPeriodTotal) * 100
    }

    private var quotaUsagePct: Double? {
        guard let pid = selectedProfileId, pid != allProfilesId,
              let profile = ProfileManager.shared.getProfile(id: pid),
              let quota = profile.quotaGB, quota > 0 else { return nil }
        return Double(totalBytes) / (quota * 1_000_000_000) * 100
    }

    private var expectedExhaustionDays: Int? {
        guard let q = quotaUsagePct, q > 0, q < 100 else { return nil }
        let days = selectedPeriod.days
        let daily = Double(totalBytes) / Double(max(days, 1))
        guard daily > 0, let profile = selectedProfileId.flatMap({ ProfileManager.shared.getProfile(id: $0) }),
              let quota = profile.quotaGB, quota > 0 else { return nil }
        let remaining = quota * 1_000_000_000 - Double(totalBytes)
        return Int(remaining / daily)
    }

    private func sessionStartTimeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("HHmmss")
        return f.string(from: date)
    }

    private func sessionDurationFormatted(_ start: Date, _ end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatTotalBytes(_ bytes: Int64) -> String {
        let b = Double(bytes)
        if b >= 1_000_000_000 { return String(format: "%.1f GB", b / 1_000_000_000) }
        if b >= 1_000_000 { return String(format: "%.1f MB", b / 1_000_000) }
        if b >= 1_000 { return String(format: "%.1f KB", b / 1_000) }
        return "\(bytes) B"
    }

    private func exportData(format: ExportFormat) {
        let pid = selectedProfileId == allProfilesId ? nil : selectedProfileId
        let data = ProfileManager.shared.exportData(profileId: pid)
        let content: String
        let ext: String
        switch format {
        case .csv: content = data.csv; ext = "csv"
        case .json: content = data.json; ext = "json"
        case .markdown: content = data.markdown; ext = "md"
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "TetherLens-export.\(ext)"
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .data]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                DebugLogger.shared.action("Export", "\(format) 내보내기 완료: \(url.lastPathComponent)")
            } catch {
                DebugLogger.shared.error("Export", "내보내기 실패: \(error.localizedDescription)")
            }
        }
    }
}
