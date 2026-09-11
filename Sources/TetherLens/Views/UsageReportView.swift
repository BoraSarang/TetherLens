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
    @State private var insights: [InsightItem] = []

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

    let preselectedProfileId: UUID?

    enum ExportFormat {
        case csv, json, markdown
    }

    init(preselectedProfileId: UUID? = nil) {
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
        // 맥 사이드바 패턴 (macos-app-design §2): NavigationSplitView + .listStyle(.sidebar)
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            rightPanel
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(Localized.exportCSV) { exportData(format: .csv) }
                    Button(Localized.exportJSON) { exportData(format: .json) }
                    Button(Localized.exportMarkdown) { exportData(format: .markdown) }
                } label: {
                    Label(Localized.export, systemImage: "square.and.arrow.up")
                }
            }
        }
        .frame(minWidth: TLSize.reportWindow.w, minHeight: TLSize.reportWindow.h)
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
        List(selection: $viewMode) {
            Section(Localized.sidebarViewSection) {
                ForEach([ViewMode.chart, .detail, .session], id: \.self) { mode in
                    Label(mode.localized, systemImage: viewModeIcon(mode))
                        .tag(mode)
                }
            }
            Section(Localized.sidebarAnalyzeSection) {
                ForEach([ViewMode.heatmap, .appTraffic, .report], id: \.self) { mode in
                    Label(mode.localized, systemImage: viewModeIcon(mode))
                        .tag(mode)
                }
            }
        }
        .listStyle(.sidebar)
        .padding(.vertical, TLSpace.sm)
    }

    private func viewModeIcon(_ mode: ViewMode) -> String {
        switch mode {
        case .chart: return "chart.bar.fill"
        case .detail: return "list.bullet"
        case .session: return "clock.fill"
        case .heatmap: return "square.grid.3x3.fill"
        case .appTraffic: return "arrow.up.arrow.down"
        case .report: return "doc.text.fill"
        }
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

            Divider()
                .padding(.horizontal, TLSpace.xl)

            contentBody
                .frame(maxHeight: .infinity, alignment: .top)

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
            ScrollView {
                VStack(spacing: 0) {
                    InsightSectionView(
                        insights: insights,
                        onShowAppTraffic: { viewMode = .appTraffic },
                        onOpenDiagnostics: { DiagnosticsWindowController.shared.show() }
                    )
                    ReportChartsView(
                        period: selectedPeriod,
                        dailyUsage: dailyUsage,
                        monthlyUsage: monthlyUsage,
                        hourlyUsage: hourlyUsage,
                        currentTotal: dailyUsage.reduce(0) { $0 + $1.total },
                        previousPeriodTotal: previousPeriodTotal,
                        recentPaceBytes: recentPaceBytes,
                        quotaRuleMarkBytes: quotaRuleMarkBytes
                    )
                }
            }
        case .detail:
            ReportDetailView(period: selectedPeriod, dailyUsage: dailyUsage, monthlyUsage: monthlyUsage)
        case .session:
            ReportSessionsView(
                period: selectedPeriod,
                sessions: sessions,
                dailySessionSummary: dailySessionSummary,
                monthlySessionSummary: monthlySessionSummary,
                profileName: sessionProfileName
            )
        case .appTraffic:
            ReportAppTrafficView(appTrafficData: appTrafficData, sortOrder: $sortOrder, expandedSection: $expandedSection)
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

    /// 세션 타임라인용 프로필명 (ReportSessionsView에 전달)
    private var sessionProfileName: String {
        if let pid = selectedProfileId {
            if pid == allProfilesId { return Localized.allProfiles }
            return ProfileManager.shared.getProfile(id: pid)?.name ?? "-"
        }
        return "-"
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
            insights = []
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
            loadPreviousPeriod()
            refreshInsights()
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
        loadPreviousPeriod()
        refreshInsights()
    }

    // MARK: - Insights (v0.36)

    /// 차트 탭에서만 계산. DB 마이그레이션 없이 ProfileManager 기존 조회로 조립한다.
    private func refreshInsights() {
        guard viewMode == .chart else {
            insights = []
            return
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let todayKey = f.string(from: Date())
        let targets: [Profile]
        if selectedProfileId == allProfilesId {
            targets = profiles
        } else {
            targets = profiles.filter { $0.id == selectedProfileId }
        }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        let pdata: [InsightInput.ProfileData] = targets.map { p in
            let t = ProfileManager.shared.getTodayUsage(profileId: p.id)
            let daily = ProfileManager.shared.getDailyUsage(profileId: p.id, days: 8)
            let hourly = ProfileManager.shared.getHourlyUsage(profileId: p.id, days: 1)
            let ipCount = Set(ProfileManager.shared.getIPLogs(profileId: p.id)
                .filter { $0.firstSeenAt >= weekAgo }
                .map(\.ipAddress)).count
            return InsightInput.ProfileData(
                id: p.id, name: p.name,
                quotaBytes: p.quotaGB.map { Int64($0 * 1_000_000_000) },
                todayUpload: t.upload, todayDownload: t.download,
                dailyTotals: daily.map { (day: $0.id, total: $0.total) },
                hourlyTotals: hourly.map { (hour: $0.hour, total: $0.total) },
                recentDistinctIPs: ipCount)
        }
        let apps = ProfileManager.shared.getAppTrafficLogs(days: 1)
            .map { (name: $0.processName, total: $0.uploadBytes + $0.downloadBytes) }
        insights = InsightEngine.build(InsightInput(topApps: apps, profiles: pdata, todayKey: todayKey, now: Date()))
        DebugLogger.shared.action("Stats", "[FEATURE] Insight \(insights.count)개 (\(insights.map(\.kind.rawValue).joined(separator: ",")))")
    }

    // MARK: - Previous Period

    /// 차트 헤더용 전기간 합계 (v0.34.2 인사이트 섹션 제거 후 잔여)
    private func loadPreviousPeriod() {
        let pid = selectedProfileId
        let days = selectedPeriod.days
        let cal = Calendar.current
        let now = Date()
        let prevTo = cal.date(byAdding: .day, value: -days, to: now)!
        let prevFrom = cal.date(byAdding: .day, value: -days * 2, to: now)!
        let effectivePid = pid == allProfilesId ? nil : pid
        previousPeriodTotal = ProfileManager.shared.getUsageTotal(profileId: effectivePid, from: prevFrom, to: prevTo)
    }

    /// 최근 3일(오늘 포함) 평균 — 기간 전체 평균보다 현재 페이스에 가까움
    private var recentPaceBytes: Int64 {
        let recent = dailyUsage.suffix(3)
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.total } / Int64(recent.count)
    }

    /// 할당량 임계선 값(바이트). 전체 프로필 또는 할당량 미설정이면 nil.
    private var quotaRuleMarkBytes: Int64? {
        guard let pid = selectedProfileId, pid != allProfilesId,
              let profile = ProfileManager.shared.getProfile(id: pid),
              let quota = profile.quotaGB, quota > 0 else { return nil }
        return Int64(quota * 1_000_000_000)
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
