import SwiftUI

/// 일별/월별 사용량 테이블. UsageReportView에서 분리 (v0.34.1).
struct ReportDetailView: View {
    let period: UsageReportView.Period
    let dailyUsage: [ProfileManager.DailyUsage]
    let monthlyUsage: [ProfileManager.MonthlyUsage]

    var body: some View {
        Group {
            let isLong = period.isLongPeriod
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
                            HoverRow {
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
                    }
                    .padding(TLSpace.md)
                    .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
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
}

/// 세션 뷰 (1일=타임라인 / 장기=월별 요약 / 그 외=일별 요약). UsageReportView에서 분리 (v0.34.1).
struct ReportSessionsView: View {
    let period: UsageReportView.Period
    let sessions: [Session]
    let dailySessionSummary: [ProfileManager.DailySessionSummary]
    let monthlySessionSummary: [ProfileManager.MonthlySessionSummary]
    let profileName: String

    var body: some View {
        Group {
            if period.days == 1 {
                SessionTimelineView(sessions: sessions, profileName: profileName)
            } else if period.isLongPeriod {
                monthlySessionSummaryView
            } else {
                dailySessionSummaryView
            }
        }
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
                            HoverRow {
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
                    }
                    .padding(TLSpace.md)
                    .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
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
                            HoverRow {
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
                    }
                    .padding(TLSpace.md)
                    .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
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
}
