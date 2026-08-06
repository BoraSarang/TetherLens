import SwiftUI
import Charts
import UniformTypeIdentifiers

struct UsageReportView: View {
    @State private var profiles: [Profile] = []
    @State private var selectedProfileId: UUID?
    @State private var selectedPeriod: Period = .week
    @State private var dailyUsage: [ProfileManager.DailyUsage] = []
    @State private var monthlyUsage: [ProfileManager.MonthlyUsage] = []
    @State private var sessions: [Session] = []
    @State private var dailySessionSummary: [ProfileManager.DailySessionSummary] = []
    @State private var monthlySessionSummary: [ProfileManager.MonthlySessionSummary] = []
    @State private var viewMode: ViewMode = .chart
    @State private var appTrafficData: [(processName: String, uploadBytes: Int64, downloadBytes: Int64)] = []
    @State private var expandedSection: AppTrafficSection = .user
    @State private var sortOrder: TrafficSortOrder = .total

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
        case csv, json
    }

    init(onClose: @escaping () -> Void, preselectedProfileId: UUID? = nil) {
        self.onClose = onClose
        self.preselectedProfileId = preselectedProfileId
    }

    private let allProfilesId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

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
        case chart, detail, session, heatmap, appTraffic
        var localized: String {
            switch self {
            case .chart: return Localized.chart
            case .detail: return Localized.detail
            case .session: return Localized.sessionTab
            case .heatmap: return Localized.heatmapTitle
            case .appTraffic: return Localized.appTrafficTab
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
        .frame(width: TLSize.sheetWide, height: 520)
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
                let totalUp = dailyUsage.reduce(0) { $0 + $1.upload }
                let totalDn = dailyUsage.reduce(0) { $0 + $1.download }
                let totalBytes = totalUp + totalDn
                let avgBytes = totalBytes / max(Int64(dailyUsage.count), 1)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Localized.totalUsage)
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textSecondary)
                        Text(totalBytes.formattedBytes)
                            .font(TLFont.callout.monospacedDigit().bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Localized.dailyAverage)
                            .font(TLFont.caption2)
                            .foregroundColor(TLPalette.textSecondary)
                        Text(avgBytes.formattedBytes)
                            .font(TLFont.callout.monospacedDigit().bold())
                    }
                }
                .padding(.vertical, TLSpace.sm)
                .background(TLPalette.textBackground.opacity(0.5))
                .cornerRadius(TLRound.small)
                .padding(.horizontal, TLSpace.xl)
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
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        if dailyUsage.isEmpty {
            Spacer()
            Text(Localized.noUsageData)
                .foregroundColor(TLPalette.textSecondary)
            Spacer()
        } else {
            let maxBytes = (dailyUsage.map { max($0.upload, $0.download) }.max() ?? 1) * 2
            let yDomain: ClosedRange<Int64> = 0 ... maxBytes
            Chart(dailyUsage) { usage in
                BarMark(
                    x: .value("Date", usage.date, unit: .day),
                    y: .value("Upload", usage.upload)
                )
                .foregroundStyle(TLPalette.upload)
                .annotation(position: .bottom, alignment: .center) {
                    Text(usage.date, format: .dateTime.day().month())
                        .font(TLFont.caption2)
                        .foregroundColor(TLPalette.textSecondary)
                }
                BarMark(
                    x: .value("Date", usage.date, unit: .day),
                    y: .value("Download", usage.download)
                )
                .foregroundStyle(TLPalette.download)
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
            sessions = allSessions.sorted { $0.startTime > $1.startTime }
            dailySessionSummary = allDailySess.values.sorted { $0.date < $1.date }
            monthlySessionSummary = allMonthlySess.values.sorted { $0.date < $1.date }
            appTrafficData = loadAppTraffic ? ProfileManager.shared.getAppTrafficLogs(days: selectedPeriod.days) : []
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
        appTrafficData = loadAppTraffic ? ProfileManager.shared.getAppTrafficLogs(days: selectedPeriod.days) : []
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
        let content = format == .csv ? data.csv : data.json
        let ext = format == .csv ? "csv" : "json"
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
