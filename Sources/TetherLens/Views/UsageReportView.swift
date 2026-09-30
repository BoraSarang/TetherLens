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

    /// DB 조회는 메인 스레드에서 하면 안 된다.
    ///
    /// 예전엔 `onChange` 에서 동기 쿼리를 돌려, 전체 프로필 + 1년 기간이면
    /// SELECT 100회 이상이 메인 스레드에서 직렬로 실행돼 창이 잠겼다 (T-250 #5).
    /// 계산은 백그라운드에서 하고, 결과만 `@MainActor` 로 돌아와 반영한다.
    private func loadData() {
        // 값 타입 스냅샷을 먼저 떼어낸다 — 계산 중 상태가 바뀌어도 결과가 섞이지 않는다.
        let request = LoadRequest(
            profileId: selectedProfileId,
            period: selectedPeriod,
            mode: viewMode,
            profiles: profiles,
            allProfilesId: allProfilesId
        )
        loadToken &+= 1
        let token = loadToken

        Task.detached(priority: .userInitiated) {
            let snapshot = Self.compute(request)
            await MainActor.run {
                // 프로필/기간을 연달아 바꾸면 이전 요청이 늦게 도착할 수 있다.
                // 가장 최근 요청 결과만 반영한다.
                guard token == self.loadToken else { return }
                self.apply(snapshot)
            }
        }
    }

    /// 계산을 수행하는 입력 — Sendable 값만 담아 백그라운드로 넘긴다
    private struct LoadRequest: Sendable {
        let profileId: UUID?
        let period: UsageReportView.Period
        let mode: UsageReportView.ViewMode
        let profiles: [Profile]
        let allProfilesId: UUID
    }

    /// 계산 결과 — `@State` 와 분리해 스레드를 넘나들 수 있게 한다
    private struct DataSnapshot: Sendable {
        var isEmptySelection = false
        var dailyUsage: [ProfileManager.DailyUsage] = []
        var monthlyUsage: [ProfileManager.MonthlyUsage] = []
        var hourlyUsage: [ProfileManager.HourlyUsage] = []
        var sessions: [Session] = []
        var dailySessionSummary: [ProfileManager.DailySessionSummary] = []
        var monthlySessionSummary: [ProfileManager.MonthlySessionSummary] = []
        var appTrafficData: [(processName: String, uploadBytes: Int64, downloadBytes: Int64)] = []
        var previousPeriodTotal: Int64 = 0
        var insights: [InsightItem] = []
    }

    /// 진행 중인 요청 구분자 — 늦게 도착한 이전 결과를 버린다
    @State private var loadToken = 0

    // MARK: - 계산 (백그라운드)

    private nonisolated static func compute(_ r: LoadRequest) -> DataSnapshot {
        var out = DataSnapshot()
        guard let pid = r.profileId else {
            out.isEmptySelection = true
            return out
        }
        let pm = ProfileManager.shared
        let period = r.period
        let loadAllSessions = r.mode == .heatmap || (r.mode == .session && period.days == 1)
        let loadAppTraffic = r.mode == .appTraffic

        if pid == r.allProfilesId {
            var allUsage: [String: ProfileManager.DailyUsage] = [:]
            var allMonthly: [String: ProfileManager.MonthlyUsage] = [:]
            var allSessions: [Session] = []
            var allDailySess: [String: ProfileManager.DailySessionSummary] = [:]
            var allMonthlySess: [String: ProfileManager.MonthlySessionSummary] = [:]
            for profile in r.profiles {
                for u in pm.getDailyUsage(profileId: profile.id, days: period.days) {
                    let existing = allUsage[u.id, default: ProfileManager.DailyUsage(id: u.id, date: u.date, upload: 0, download: 0)]
                    allUsage[u.id] = ProfileManager.DailyUsage(id: u.id, date: u.date, upload: existing.upload + u.upload, download: existing.download + u.download)
                }
                if loadAllSessions {
                    allSessions.append(contentsOf: pm.getSessions(profileId: profile.id, days: period.days))
                }
                if period.isLongPeriod {
                    let months = period.months
                    for u in pm.getMonthlyUsage(profileId: profile.id, months: months) {
                        let existing = allMonthly[u.id, default: ProfileManager.MonthlyUsage(id: u.id, date: u.date, upload: 0, download: 0)]
                        allMonthly[u.id] = ProfileManager.MonthlyUsage(id: u.id, date: u.date, upload: existing.upload + u.upload, download: existing.download + u.download)
                    }
                    for sm in pm.getMonthlySessionSummary(profileId: profile.id, months: months) {
                        let existing = allMonthlySess[sm.id, default: ProfileManager.MonthlySessionSummary(id: sm.id, date: sm.date, sessionCount: 0, totalDuration: 0)]
                        allMonthlySess[sm.id] = ProfileManager.MonthlySessionSummary(id: sm.id, date: sm.date, sessionCount: existing.sessionCount + sm.sessionCount, totalDuration: existing.totalDuration + sm.totalDuration)
                    }
                } else if period.days > 1 {
                    for sm in pm.getDailySessionSummary(profileId: profile.id, days: period.days) {
                        let existing = allDailySess[sm.id, default: ProfileManager.DailySessionSummary(id: sm.id, date: sm.date, sessionCount: 0, totalDuration: 0)]
                        allDailySess[sm.id] = ProfileManager.DailySessionSummary(id: sm.id, date: sm.date, sessionCount: existing.sessionCount + sm.sessionCount, totalDuration: existing.totalDuration + sm.totalDuration)
                    }
                }
            }
            out.dailyUsage = allUsage.values.sorted { $0.date < $1.date }
            out.monthlyUsage = allMonthly.values.sorted { $0.date < $1.date }
            if period.days == 1 {
                var allHourly: [Int: ProfileManager.HourlyUsage] = [:]
                for profile in r.profiles {
                    for h in pm.getHourlyUsage(profileId: profile.id, days: 1) {
                        let existing = allHourly[h.hour, default: ProfileManager.HourlyUsage(id: h.hour, hour: h.hour, upload: 0, download: 0)]
                        allHourly[h.hour] = ProfileManager.HourlyUsage(id: h.hour, hour: h.hour, upload: existing.upload + h.upload, download: existing.download + h.download)
                    }
                }
                out.hourlyUsage = allHourly.values.sorted { $0.hour < $1.hour }
            }
            out.sessions = allSessions.sorted { $0.startTime > $1.startTime }
            out.dailySessionSummary = allDailySess.values.sorted { $0.date < $1.date }
            out.monthlySessionSummary = allMonthlySess.values.sorted { $0.date < $1.date }
        } else {
            out.dailyUsage = pm.getDailyUsage(profileId: pid, days: period.days)
            if period.isLongPeriod {
                out.monthlyUsage = pm.getMonthlyUsage(profileId: pid, months: period.months)
                out.monthlySessionSummary = pm.getMonthlySessionSummary(profileId: pid, months: period.months)
                out.sessions = loadAllSessions ? pm.getSessions(profileId: pid, days: period.days) : []
            } else if period.days > 1 {
                out.sessions = loadAllSessions ? pm.getSessions(profileId: pid, days: period.days) : []
                out.dailySessionSummary = pm.getDailySessionSummary(profileId: pid, days: period.days)
            } else {
                out.sessions = pm.getSessions(profileId: pid, days: period.days)
            }
            out.hourlyUsage = period.days == 1 ? pm.getHourlyUsage(profileId: pid, days: 1) : []
        }

        out.appTrafficData = loadAppTraffic ? pm.getAppTrafficLogs(days: period.days) : []
        out.previousPeriodTotal = previousPeriodTotal(days: period.days, profileId: pid, allProfilesId: r.allProfilesId)
        // ⚠️ 프로필별로 쪼개서 합치지 않는다. `topOffender` 같은 인사이트는
        // 전체 프로필을 한 번에 넘겨야 계산되므로(전역 집계) 대상을 통째로 넘긴다.
        out.insights = r.mode == .chart ? InsightProvider.build(profiles: insightTargets(for: r)) : []
        return out
    }

    private nonisolated static func previousPeriodTotal(days: Int, profileId: UUID, allProfilesId: UUID) -> Int64 {
        let cal = Calendar.current
        let now = Date()
        guard let prevTo = cal.date(byAdding: .day, value: -days, to: now),
              let prevFrom = cal.date(byAdding: .day, value: -days * 2, to: now) else { return 0 }
        let effectivePid = profileId == allProfilesId ? nil : profileId
        return ProfileManager.shared.getUsageTotal(profileId: effectivePid, from: prevFrom, to: prevTo)
    }

    /// 차트 탭에서 인사이트를 볼 대상 프로필 (인사이트는 프로필 단위로 계산된다)
    private nonisolated static func insightTargets(for r: LoadRequest) -> [Profile] {
        r.profileId == r.allProfilesId ? r.profiles : r.profiles.filter { $0.id == r.profileId }
    }

    // MARK: - 적용 (메인 스레드)

    private func apply(_ out: DataSnapshot) {
        if out.isEmptySelection {
            dailyUsage = []
            monthlyUsage = []
            hourlyUsage = []
            sessions = []
            dailySessionSummary = []
            monthlySessionSummary = []
            appTrafficData = []
            previousPeriodTotal = 0
            insights = []
            return
        }
        dailyUsage = out.dailyUsage
        monthlyUsage = out.monthlyUsage
        hourlyUsage = out.hourlyUsage
        sessions = out.sessions
        dailySessionSummary = out.dailySessionSummary
        monthlySessionSummary = out.monthlySessionSummary
        appTrafficData = out.appTrafficData
        previousPeriodTotal = out.previousPeriodTotal
        insights = out.insights
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
