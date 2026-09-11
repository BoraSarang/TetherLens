import SwiftUI
import Charts

/// 사용량 차트 (기간별 막대 + pace/quota 기준선). UsageReportView에서 분리 (v0.34.1).
struct ReportChartsView: View {
    let period: UsageReportView.Period
    let dailyUsage: [ProfileManager.DailyUsage]
    let monthlyUsage: [ProfileManager.MonthlyUsage]
    let hourlyUsage: [ProfileManager.HourlyUsage]
    let currentTotal: Int64
    let previousPeriodTotal: Int64
    let recentPaceBytes: Int64
    let quotaRuleMarkBytes: Int64?

    var body: some View {
        let isDay = period.days == 1
        let isWeekly = period.days == 7
        let isLong = period.isLongPeriod
        let source = chartDataSource
        if source.isEmpty {
            Spacer()
            Text(Localized.noUsageData)
                .foregroundColor(TLPalette.textSecondary)
            Spacer()
        } else {
            HStack {
                Text(period.localized)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
                Text(previousPeriodText)
                    .font(TLFont.caption.monospacedDigit().bold())
                    .foregroundColor(previousPeriodColor)
            }
            .help("\(Localized.prevPeriod) \(previousPeriodTotal.formattedBytes)")
            .padding(.horizontal, TLSpace.xl)
            let peakBar = source.map { $0.upload + $0.download }.max() ?? 1
            let peakQuota = quotaRuleMarkBytes ?? 0
            let yTop = max(peakBar, peakQuota) * 11 / 10
            let yDomain: ClosedRange<Int64> = 0 ... max(yTop, 1)
            Chart {
                // 기준선은 막대 뒤에 그려 겹침을 방지한다
                if recentPaceBytes > 0 {
                    RuleMark(
                        y: .value("Pace", recentPaceBytes)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(TLPalette.accent.opacity(0.5))
                    .annotation(position: .top, alignment: .leading) {
                        Text(Localized.paceLabel)
                            .font(TLFont.small)
                            .foregroundColor(TLPalette.accent.opacity(0.8))
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
            .padding(TLSpace.md)
            .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
            .padding(.horizontal, TLSpace.xl)
            .frame(height: 304)
            .clipped()
        }
    }

    private var previousPeriodPct: Double? {
        guard previousPeriodTotal > 0 else { return nil }
        return (Double(currentTotal) - Double(previousPeriodTotal)) / Double(previousPeriodTotal) * 100
    }

    private var previousPeriodText: String {
        guard let pct = previousPeriodPct else { return "—" }
        return "\(pct >= 0 ? "▲" : "▼") \(String(format: "%.1f%%", abs(pct)))"
    }

    private var previousPeriodColor: Color {
        guard let pct = previousPeriodPct else { return TLPalette.textSecondary }
        return pct > 0 ? TLPalette.upload : TLPalette.success
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
        if period.days == 1 {
            return hourlyChartData
        } else if period.days == 7 {
            return weeklyChartData
        } else if period.isLongPeriod {
            return longChartData
        } else {
            return monthlyChartData
        }
    }

    /// day(1일) — 시간대(0~23)별, 0인 시간은 빈 값으로 채움
    private var hourlyChartData: [ChartEntry] {
        let byHour = Dictionary(uniqueKeysWithValues: hourlyUsage.map { ($0.hour, $0) })
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
}
