import SwiftUI
import Charts

struct UsageReportView: View {
    @State private var profiles: [Profile] = []
    @State private var selectedProfileId: UUID?
    @State private var selectedPeriod: Period = .week
    @State private var dailyUsage: [ProfileManager.DailyUsage] = []
    @State private var sessions: [Session] = []
    @State private var viewMode: ViewMode = .chart

    let onClose: () -> Void

    enum Period: String, CaseIterable {
        case day = "1일"
        case week = "7일"
        case month = "30일"
        case all = "90일"

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .all: return 90
            }
        }
    }

    enum ViewMode: String, CaseIterable {
        case chart = "그래프"
        case detail = "상세"
        case session = "세션"
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
        .frame(width: 440, height: 460)
        .onAppear {
            profiles = ProfileManager.shared.getAllProfiles()
            selectedProfileId = profiles.first?.id
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
        .frame(width: 72)
        .padding(.vertical, 8)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("", selection: $selectedProfileId) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                .padding(.horizontal, 12)
            }

            Divider()
                .padding(.horizontal, 12)

            contentBody

            HStack {
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
            Chart(dailyUsage.reversed()) { usage in
                BarMark(
                    x: .value("날짜", usage.date, unit: .day),
                    y: .value("업로드", usage.upload)
                )
                .foregroundStyle(.orange)
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
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 12)
            Spacer()
        }
    }

    // MARK: - Detail

    private var detailView: some View {
        Group {
            if dailyUsage.isEmpty {
                Spacer()
                Text("사용량 데이터가 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(dailyUsage) { usage in
                    HStack {
                        Text(usage.date, style: .date)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        Spacer(minLength: 4)
                        Text("↑ \(usage.upload.formattedBytes)")
                            .font(.caption.monospacedDigit())
                            .frame(width: 80, alignment: .trailing)
                        Text("↓ \(usage.download.formattedBytes)")
                            .font(.caption.monospacedDigit())
                            .frame(width: 80, alignment: .trailing)
                        Text("\(usage.total.formattedBytes)")
                            .font(.caption.monospacedDigit().bold())
                            .frame(width: 72, alignment: .trailing)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Session

    private var sessionView: some View {
        Group {
            if sessions.isEmpty {
                Spacer()
                Text("세션 데이터가 없습니다")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(sessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.startTime, style: .date)
                                .font(.caption)
                            Text(sessionStartTimeFormatted(session.startTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
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
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func loadData() {
        guard let pid = selectedProfileId else {
            dailyUsage = []
            sessions = []
            return
        }
        dailyUsage = ProfileManager.shared.getDailyUsage(profileId: pid, days: selectedPeriod.days)
        sessions = ProfileManager.shared.getSessions(profileId: pid, days: selectedPeriod.days)
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
}
