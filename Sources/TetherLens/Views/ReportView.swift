import SwiftUI

struct ReportView: View {
  let profiles: [Profile]
  let selectedProfileId: UUID?
  let selectedPeriod: UsageReportView.Period

  @State private var copied = false

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
      }
      .padding(.horizontal, TLSpace.xl)
      .padding(.vertical, TLSpace.md)

      Divider()

      if effectiveProfiles.isEmpty {
        Spacer()
        Text(Localized.noUsageData)
          .foregroundColor(TLPalette.textSecondary)
        Spacer()
      } else {
        ScrollView {
          Text(markdown)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(TLPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TLSpace.xl)
        }
      }
    }
  }
}
