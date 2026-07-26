import SwiftUI
import Charts

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

    enum TrafficSortOrder: String, CaseIterable {
        case total = "전체 순"
        case upload = "업로드 순"
        case download = "다운로드 순"
    }

    enum AppTrafficSection {
        case user
        case system
    }

    let onClose: () -> Void
    let preselectedProfileId: UUID?

    init(onClose: @escaping () -> Void, preselectedProfileId: UUID? = nil) {
        self.onClose = onClose
        self.preselectedProfileId = preselectedProfileId
    }

    private let allProfilesId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    enum Period: String, CaseIterable {
        case day = "1일"
        case week = "7일"
        case month = "30일"
        case halfYear = "6개월"
        case year = "1년"

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

    enum ViewMode: String, CaseIterable {
        case chart = "그래프"
        case detail = "상세"
        case session = "세션"
        case appTraffic = "프로세스별 트래픽"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("사용량 리포트")
                    .font(.headline)
                    .padding(.leading, 16)
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            HStack(spacing: 0) {
                sidebar
                Divider()
                rightPanel
            }
        }
        .frame(width: 520, height: 480)
        .onAppear {
            profiles = ProfileManager.shared.getAllProfiles()
            selectedProfileId = preselectedProfileId ?? allProfilesId
            loadData()
        }
        .onChange(of: selectedProfileId) { _, _ in loadData() }
        .onChange(of: selectedPeriod) { _, _ in loadData() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    viewMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .foregroundColor(viewMode == mode ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(viewMode == mode ? Color.accentColor.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(width: 88)
        .padding(.vertical, 8)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("", selection: $selectedProfileId) {
                    Text("전체 프로필").tag(allProfilesId as UUID?)
                    ForEach(profiles) { profile in
                        Text(profile.name).tag(profile.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 140)

                Picker("", selection: $selectedPeriod) {
                    ForEach(Period.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if !dailyUsage.isEmpty {
                let totalUp = dailyUsage.reduce(0) { $0 + $1.upload }
                let totalDn = dailyUsage.reduce(0) { $0 + $1.download }
                let totalBytes = totalUp + totalDn
                let avgBytes = totalBytes / max(Int64(dailyUsage.count), 1)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("총 사용량")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(totalBytes.formattedBytes)
                            .font(.callout.monospacedDigit().bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("일 평균")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(avgBytes.formattedBytes)
                            .font(.callout.monospacedDigit().bold())
                    }
                }
                .padding(.vertical, 6)
                .background(Color(.textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                .padding(.horizontal, 12)
            }

            Divider()
                .padding(.horizontal, 12)

            contentBody

            HStack {
                HStack(spacing: 8) {
                    Text("▲ 업로드")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    Text("▼ 다운로드")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
                Spacer()
                Button("닫기", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
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
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        if dailyUsage.isEmpty {
            Spacer()
            Text("사용량 데이터가 없습니다")
                .foregroundColor(.secondary)
            Spacer()
        } else {
            let maxBytes = (dailyUsage.map { max($0.upload, $0.download) }.max() ?? 1) * 2
            let yDomain: ClosedRange<Int64> = 0 ... maxBytes
            Chart(dailyUsage.reversed()) { usage in
                BarMark(
                    x: .value("날짜", usage.date, unit: .day),
                    y: .value("업로드", usage.upload)
                )
                .foregroundStyle(.orange)
                .annotation(position: .bottom, alignment: .center) {
                    Text(usage.date, format: .dateTime.day().month())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                BarMark(
                    x: .value("날짜", usage.date, unit: .day),
                    y: .value("다운로드", usage.download)
                )
                .foregroundStyle(.blue)
            }
            .chartForegroundStyleScale([
                "업로드": Color.orange,
                "다운로드": Color.blue
            ])
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            Text(formatTotalBytes(Int64(bytes)))
                                .font(.system(size: 9))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
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
                Text("사용량 데이터가 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text(isLong ? "월" : "날짜")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Text("▲ 업로드")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("▼ 다운로드")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 72, alignment: .trailing)
                            Text("합계")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        ForEach(items) { item in
                            Divider()
                            HStack(spacing: 0) {
                                if item.isMonthly {
                                    Text(item.date, format: .dateTime.month().year())
                                        .font(.caption)
                                        .frame(width: 72, alignment: .leading)
                                } else {
                                    Text(item.date, format: .dateTime.day().month())
                                        .font(.caption)
                                        .frame(width: 72, alignment: .leading)
                                }
                                Text(item.upload.formattedBytes)
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(item.download.formattedBytes)
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.blue)
                                    .frame(width: 72, alignment: .trailing)
                                Text(item.total.formattedBytes)
                                    .font(.caption.monospacedDigit().bold())
                                    .frame(width: 72, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 12)
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
        Group {
            if sessions.isEmpty {
                Spacer()
                Text("세션 데이터가 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("시작 시간")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("상태")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        ForEach(sessions) { session in
                            Divider()
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.startTime, style: .date)
                                        .font(.caption)
                                    Text(sessionStartTimeFormatted(session.startTime))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let end = session.endTime {
                                        Text(sessionDurationFormatted(session.startTime, end))
                                            .font(.caption.monospacedDigit())
                                    } else {
                                        Text("진행 중")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                .frame(width: 72, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private var dailySessionSummaryView: some View {
        Group {
            if dailySessionSummary.isEmpty {
                Spacer()
                Text("세션 데이터가 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("날짜")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("세션")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 44, alignment: .trailing)
                            Text("시간")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 64, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        ForEach(dailySessionSummary) { item in
                            Divider()
                            HStack(spacing: 0) {
                                Text(item.date, format: .dateTime.day().month())
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(item.sessionCount)")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 44, alignment: .trailing)
                                Text(formatDuration(item.totalDuration))
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 64, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private var monthlySessionSummaryView: some View {
        Group {
            if monthlySessionSummary.isEmpty {
                Spacer()
                Text("세션 데이터가 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("월")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("세션")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 44, alignment: .trailing)
                            Text("시간")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 64, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        ForEach(monthlySessionSummary) { item in
                            Divider()
                            HStack(spacing: 0) {
                                Text(item.date, format: .dateTime.month().year())
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(item.sessionCount)")
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 44, alignment: .trailing)
                                Text(formatDuration(item.totalDuration))
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 64, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 12)
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
                Text("트래픽 데이터가 없습니다")
                    .foregroundColor(.secondary)
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
                            Text("프로세스")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("▲ 업로드")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.orange)
                                .frame(width: 68, alignment: .trailing)
                            Text("▼ 다운로드")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 68, alignment: .trailing)
                        }
                        .frame(height: 20)

                        Divider()

                        summaryRow(label: "총 합계", upload: totalUp, download: totalDn, isBold: true)
                        summaryRow(label: "사용자 합계", upload: userUp, download: userDn, isBold: true)
                        summaryRow(label: "시스템 합계", upload: sysUp, download: sysDn, isBold: true)

                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 0) {
                            Spacer()
                            Picker("정렬", selection: $sortOrder) {
                                ForEach(TrafficSortOrder.allCases, id: \.self) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.bottom, 4)
                    }
                    .padding(.horizontal, 12)

                    Divider()
                        .padding(.horizontal, 12)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                Button {
                                    withAnimation {
                                        expandedSection = expandedSection == .user ? .system : .user
                                        proxy.scrollTo("top", anchor: .top)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: expandedSection == .user ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                        Text("사용자 프로세스 (상위 10)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 6)
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
                                    HStack(spacing: 4) {
                                        Image(systemName: expandedSection == .system ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    Text("시스템 프로세스 (상위 10)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            if expandedSection == .system {
                                ForEach(Array(systemApps.prefix(10).enumerated()), id: \.element.processName) { _, item in
                                        Divider()
                                        appTrafficRow(item)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(label: String, upload: Int64, download: Int64, isBold: Bool) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: isBold ? .bold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTotalBytes(upload))
                .font(.system(size: 10, weight: isBold ? .bold : .regular, design: .monospaced))
                .foregroundColor(.orange)
                .frame(width: 68, alignment: .trailing)
            Text(formatTotalBytes(download))
                .font(.system(size: 10, weight: isBold ? .bold : .regular, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 68, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func appTrafficRow(_ item: (processName: String, uploadBytes: Int64, downloadBytes: Int64)) -> some View {
        HStack(spacing: 0) {
            Text(item.processName)
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTotalBytes(item.uploadBytes))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.orange)
                .frame(width: 68, alignment: .trailing)
            Text(formatTotalBytes(item.downloadBytes))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 68, alignment: .trailing)
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
                allSessions.append(contentsOf: ProfileManager.shared.getSessions(profileId: profile.id, days: selectedPeriod.days))
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
            appTrafficData = ProfileManager.shared.getAppTrafficLogs(days: selectedPeriod.days)
            return
        }
        dailyUsage = ProfileManager.shared.getDailyUsage(profileId: pid, days: selectedPeriod.days)
        if selectedPeriod.isLongPeriod {
            monthlyUsage = ProfileManager.shared.getMonthlyUsage(profileId: pid, months: selectedPeriod.months)
            monthlySessionSummary = ProfileManager.shared.getMonthlySessionSummary(profileId: pid, months: selectedPeriod.months)
            sessions = []
            dailySessionSummary = []
        } else if selectedPeriod.days > 1 {
            sessions = []
            dailySessionSummary = ProfileManager.shared.getDailySessionSummary(profileId: pid, days: selectedPeriod.days)
            monthlySessionSummary = []
        } else {
            sessions = ProfileManager.shared.getSessions(profileId: pid, days: 1)
            dailySessionSummary = []
            monthlySessionSummary = []
        }
        appTrafficData = ProfileManager.shared.getAppTrafficLogs(days: selectedPeriod.days)
    }

    private func sessionStartTimeFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
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
}
