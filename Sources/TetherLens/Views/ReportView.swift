import SwiftUI

struct ReportView: View {
  let profiles: [Profile]
  let selectedProfileId: UUID?
  let selectedPeriod: UsageReportView.Period

  @State private var copied = false
  @State private var showSource = false
  @State private var cachedMarkdown: String?
  @State private var cachedKey: String?
  @State private var cachedSummary: ProfileManager.ReportSummary?
  @State private var cachedSummaryKey: String?

  private let allProfilesId = UsageReportView.ReportAllProfilesId

  private static let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  /// 캐시 무효화 키 — 기간, 선택 프로필, **그리고 대상 프로필 목록**을 모두 담는다.
  /// (프로필이 추가/삭제돼도 캐시가 남아 있으면 갱신 신호를 놓친다)
  private var cacheKey: String {
    let ids = effectiveProfiles.map(\.id.uuidString).joined(separator: ",")
    return "\(selectedPeriod.days)|\(selectedProfileId?.uuidString ?? "all")|\(ids)"
  }

  private var effectiveProfiles: [Profile] {
    guard let pid = selectedProfileId, pid != allProfilesId else { return profiles }
    return profiles.filter { $0.id == pid }
  }

  private var periodLabel: String {
    selectedPeriod.localized
  }

  private var dateRangeLabel: String {
    let f = Self.dayFormatter
    let to = Date()
    let from = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days + 1, to: to) ?? to
    return "\(f.string(from: from)) ~ \(f.string(from: to))"
  }

  /// DB 집계는 **프로필/기간이 바뀔 때만** 수행한다.
  ///
  /// 예전엔 계산 프로퍼티라 `renderedBody` 가 평가될 때마다
  /// (프로필당 3쿼리 + 세션별 N+1) 를 새로 돌렸다 (T-250 #4).
  /// 렌더/원문 토글이나 `copied` 변경 같은 가벼운 상태 변화만으로도 다시 조회됐다.
  private var summary: ProfileManager.ReportSummary {
    if let c = cachedSummary, cachedSummaryKey == cacheKey { return c }
    return fetchSummary()
  }

  private func fetchSummary() -> ProfileManager.ReportSummary {
    ProfileManager.shared.reportSummary(profileIds: effectiveProfiles.map(\.id), days: selectedPeriod.days)
  }

  /// 캐시 채움은 body 평가가 아니라 명시적 신호(등장/키 변경)에서만 한다.
  /// body 안에서 `@State` 를 바꾸는 건 부작용이라 피한다.
  private func refreshSummaryCache() {
    cachedSummary = fetchSummary()
    cachedSummaryKey = cacheKey
  }

  // MARK: - 마크다운

  /// body 재평가마다 DB 쿼리+문자열 합성하지 않도록 프로필/기간 변경 시 1회 갱신 (v0.38.2).
  private func markdownIfNeeded() -> String {
    if let cached = cachedMarkdown, cachedKey == cacheKey { return cached }
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
      lines.append("트래픽 데이터가 없습니다.")
    } else {
      lines.append("| 앱 | 사용량 |")
      lines.append("|----|--------|")
      for app in s.topApps {
        lines.append("| \(app.name) | \(app.total.formattedBytes) |")
      }
    }
    let text = lines.joined(separator: "\n")
    cachedMarkdown = text
    cachedKey = cacheKey
    return text
  }

  private var markdown: String { markdownIfNeeded() }

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
    .onAppear { refreshSummaryCache() }
    .onChange(of: cacheKey) { _, _ in refreshSummaryCache() }
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
            ForEach(Array(entries.enumerated()), id: \.element.profileId) { idx, q in
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
          Text(Localized.string("트래픽 데이터가 없습니다.", "No traffic data."))
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
