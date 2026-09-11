import SwiftUI

struct ReportView: View {
  let profiles: [Profile]
  let selectedProfileId: UUID?
  let selectedPeriod: UsageReportView.Period

  @State private var copied = false
  @State private var showSource = false

  private let allProfilesId = UsageReportView.ReportAllProfilesId

  private var effectiveProfiles: [Profile] {
    guard let pid = selectedProfileId, pid != allProfilesId else { return profiles }
    return profiles.filter { $0.id == pid }
  }

  private var periodLabel: String {
    selectedPeriod.localized
  }

  private var dateRangeLabel: String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    let to = Date()
    let from = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days + 1, to: to) ?? to
    return "\(f.string(from: from)) ~ \(f.string(from: to))"
  }

  private var summary: ProfileManager.ReportSummary {
    ProfileManager.shared.reportSummary(profileIds: effectiveProfiles.map(\.id), days: selectedPeriod.days)
  }

  // MARK: - 마크다운

  private var markdown: String {
    let s = summary
    let total = s.totalUpload + s.totalDownload
    var lines: [String] = []
    lines.append("# TetherLens 사용량 리포트")
    lines.append("")
    lines.append("- 기간: \(periodLabel) (\(dateRangeLabel))")
    lines.append("- 프로필: \(effectiveProfiles.map(\.name).joined(separator: ", "))")
    lines.append("- 총 사용량: \(total.formattedBytes) (업로드 \(s.totalUpload.formattedBytes) / 다운로드 \(s.totalDownload.formattedBytes))")
    lines.append("")
    lines.append("## 프로필별 할당량")
    lines.append("")
    if s.quotaEntries.allSatisfy({ $0.quotaBytes == nil }) {
      lines.append("할당량이 설정된 프로필이 없습니다.")
    } else {
      lines.append("| 프로필 | 사용량 | 할당량 | 달성률 |")
      lines.append("|--------|--------|--------|--------|")
      for q in s.quotaEntries where q.quotaBytes != nil {
        let pct = q.quotaBytes! > 0 ? min(Int(q.used * 100 / q.quotaBytes!), 999) : 0
        lines.append("| \(q.profileName) | \(q.used.formattedBytes) | \(q.quotaBytes!.formattedBytes) | \(pct)% |")
      }
    }
    lines.append("")
    lines.append("## 핫스팟 사용 현황")
    lines.append("")
    lines.append("- 세션 수: \(s.totalSessions)")
    lines.append("- 이동 이력(위치/IP 변경): \(s.movementCount)건")
    lines.append("")
    lines.append("## 상위 앱")
    lines.append("")
    if s.topApps.isEmpty {
      lines.append("앱 트래픽 데이터가 없습니다.")
    } else {
      lines.append("| 앱 | 사용량 |")
      lines.append("|----|--------|")
      for app in s.topApps {
        lines.append("| \(app.name) | \(app.total.formattedBytes) |")
      }
    }
    return lines.joined(separator: "\n")
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: TLSpace.md) {
        Text(Localized.string("리포트 미리보기", "Report Preview"))
          .font(TLFont.subheadline.bold())
        Spacer()
        Picker("", selection: $showSource) {
          Text(Localized.reportRendered).tag(false)
          Text(Localized.reportSource).tag(true)
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(markdown, forType: .string)
          copied = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
          Label(copied ? Localized.copied : Localized.copy, systemImage: copied ? "checkmark" : "doc.on.doc")
            .font(TLFont.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(Localized.string("마크다운 원문 복사", "Copy raw markdown"))
      }
      .padding(.horizontal, TLSpace.xl)
      .padding(.vertical, TLSpace.md)

      Divider()

      if effectiveProfiles.isEmpty {
        Spacer()
        Text(Localized.noUsageData)
          .foregroundColor(TLPalette.textSecondary)
        Spacer()
      } else if showSource {
        ScrollView {
          Text(markdown)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(TLPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TLSpace.xl)
            .textSelection(.enabled)
        }
      } else {
        ScrollView {
          renderedBody
            .padding(TLSpace.xl)
        }
      }
    }
  }

  // MARK: - 렌더링 (v0.36.1)

  /// 마크다운 파싱 대신 요약 데이터 직접 렌더링 — 스키마 고정이라 파싱 불필요.
  private var renderedBody: some View {
    let s = summary
    let total = s.totalUpload + s.totalDownload
    return VStack(alignment: .leading, spacing: TLSpace.md) {
      Text(Localized.string("TetherLens 사용량 리포트", "TetherLens Usage Report"))
        .font(TLFont.headline)
        .foregroundColor(TLPalette.textPrimary)
      VStack(alignment: .leading, spacing: 2) {
        metaRow(Localized.string("기간", "Period"), "\(periodLabel) (\(dateRangeLabel))")
        metaRow(Localized.string("프로필", "Profiles"), effectiveProfiles.map(\.name).joined(separator: ", "))
        metaRow(Localized.string("총 사용량", "Total"),
                "\(total.formattedBytes) (\(Localized.string("업로드", "Up")) \(s.totalUpload.formattedBytes) / \(Localized.string("다운로드", "Dn")) \(s.totalDownload.formattedBytes))")
      }
      renderSection(Localized.string("프로필별 할당량", "Quota by Profile")) {
        let entries = s.quotaEntries.filter { $0.quotaBytes != nil }
        if entries.isEmpty {
          Text(Localized.string("할당량이 설정된 프로필이 없습니다.", "No profiles with quota."))
            .font(TLFont.caption)
            .foregroundColor(TLPalette.textSecondary)
        } else {
          Grid(alignment: .leading, horizontalSpacing: TLSpace.xl, verticalSpacing: 4) {
            GridRow {
              Text(Localized.string("프로필", "Profile"))
              Text(Localized.string("사용량", "Used"))
              Text(Localized.string("할당량", "Quota"))
              Text(Localized.string("달성률", "Rate"))
            }
            .font(TLFont.caption.bold())
            .foregroundColor(TLPalette.textSecondary)
            Divider().gridCellColumns(4)
            ForEach(Array(entries.enumerated()), id: \.element.profileName) { idx, q in
              GridRow {
                Text(q.profileName)
                Text(q.used.formattedBytes).monospacedDigit()
                Text((q.quotaBytes ?? 0).formattedBytes).monospacedDigit()
                Text("\(quotaPercent(used: q.used, quota: q.quotaBytes))%")
                  .monospacedDigit()
                  .foregroundColor(quotaColor(used: q.used, quota: q.quotaBytes))
              }
              .font(TLFont.detail)
              .foregroundColor(TLPalette.textPrimary)
              .padding(.vertical, 3)
              .padding(.horizontal, 8)
              .background(stripeBackground(idx))
              .cornerRadius(6)
            }
          }
        }
      }
      renderSection(Localized.string("핫스팟 사용 현황", "Hotspot Sessions")) {
        metaRow(Localized.string("세션 수", "Sessions"), "\(s.totalSessions)")
        metaRow(Localized.string("이동 이력", "Movements"), Localized.string("\(s.movementCount)건", "\(s.movementCount) events"))
      }
      renderSection(Localized.string("상위 앱", "Top Apps")) {
        if s.topApps.isEmpty {
          Text(Localized.string("앱 트래픽 데이터가 없습니다.", "No app traffic data."))
            .font(TLFont.caption)
            .foregroundColor(TLPalette.textSecondary)
        } else {
          Grid(alignment: .leading, horizontalSpacing: TLSpace.xl, verticalSpacing: 4) {
            GridRow {
              Text(Localized.string("앱", "App"))
              Text(Localized.string("사용량", "Used"))
            }
            .font(TLFont.caption.bold())
            .foregroundColor(TLPalette.textSecondary)
            Divider().gridCellColumns(2)
            ForEach(Array(s.topApps.enumerated()), id: \.element.name) { idx, app in
              GridRow {
                Text(app.name)
                Text(app.total.formattedBytes).monospacedDigit()
              }
              .font(TLFont.detail)
              .foregroundColor(TLPalette.textPrimary)
              .padding(.vertical, 3)
              .padding(.horizontal, 8)
              .background(stripeBackground(idx))
              .cornerRadius(6)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func renderSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: TLSpace.xs) {
      Text(title)
        .font(TLFont.smallBold)
        .foregroundColor(TLPalette.textSecondary)
      content()
        .padding(12)
        .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
    }
  }

  private func metaRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: TLSpace.sm) {
      Text(label)
        .font(TLFont.detail)
        .foregroundColor(TLPalette.textSecondary)
        .frame(minWidth: 64, alignment: .leading)
      Text(value)
        .font(TLFont.detail)
        .foregroundColor(TLPalette.textPrimary)
    }
  }

  private func stripeBackground(_ idx: Int) -> Color {
    idx % 2 == 1 ? TLPalette.separator.opacity(0.25) : .clear
  }

  private func quotaPercent(used: Int64, quota: Int64?) -> Int {    guard let quota = quota, quota > 0 else { return 0 }
    return min(Int(used * 100 / quota), 999)
  }

  private func quotaColor(used: Int64, quota: Int64?) -> Color {
    let pct = quotaPercent(used: used, quota: quota)
    if pct >= 90 { return TLPalette.danger }
    if pct >= 70 { return TLPalette.upload }
    return TLPalette.textPrimary
  }
}
