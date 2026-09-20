import SwiftUI

// MARK: - 릴리스 노트 마크다운 렌더러 (macOS-app-update 가이드)
//
// AttributedString(markdown:) 전체 구문을 쓰면 블록 경계가 줄바꿈으로 그려지지 않아
// 제목·목록이 한 덩어리로 붙는다. 아래 방식을 사용한다:
//   1. 줄 단위로 블록 분류 (제목·글머리·번호·인용·코드·문단)
//   2. 각 줄은 .inlineOnlyPreservingWhitespace로 인라인(굵기·기울임·코드)만 해석
//   3. 글자 크기는 run마다 직접 기록 — View 뒤의 .font()는 볼드 특성을 덮으므로 금지

/// 인라인 마크다운만 해석한 AttributedString (폰트는 run마다 기록)
func updateStyledInline(_ s: String, size: CGFloat, bold: Bool = false, italic: Bool = false) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace)
    var attr = (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
    for run in attr.runs {
        var font = Font.system(size: size)
        let intent = run.inlinePresentationIntent
        if bold || intent?.contains(.stronglyEmphasized) == true { font = font.bold() }
        if italic || intent?.contains(.emphasized) == true { font = font.italic() }
        if intent?.contains(.code) == true {
            font = Font.system(size: size, design: .monospaced)
        }
        attr[run.range].font = font
    }
    return attr
}

struct ReleaseNotesView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                let lines = markdown.components(separatedBy: "\n")
                ForEach(Array(lines.enumerated()), id: \.offset) { _, raw in
                    renderLine(raw)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TLSpace.lg)
        }
    }

    @ViewBuilder
    private func renderLine(_ raw: String) -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else if trimmed.hasPrefix("### ") {
            heading(String(trimmed.dropFirst(4)), size: 13, topPadding: 2)
        } else if trimmed.hasPrefix("## ") {
            heading(String(trimmed.dropFirst(3)), size: 14, topPadding: 4)
        } else if trimmed.hasPrefix("# ") {
            heading(String(trimmed.dropFirst(2)), size: 15, topPadding: 6)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            bullet(String(trimmed.dropFirst(2)))
        } else if trimmed.hasPrefix("> ") {
            quote(String(trimmed.dropFirst(2)))
        } else if trimmed == "```" {
            Text(updateStyledInline(trimmed, size: 11))
                .foregroundColor(TLPalette.textSecondary)
        } else {
            Text(updateStyledInline(trimmed, size: 11))
                .foregroundColor(TLPalette.textPrimary)
        }
    }

    private func heading(_ text: String, size: CGFloat, topPadding: CGFloat) -> some View {
        Text(updateStyledInline(text, size: size, bold: true))
            .foregroundColor(TLPalette.textPrimary)
            .padding(.top, topPadding)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("•")
                .font(.system(size: 11))
                .foregroundColor(TLPalette.textSecondary)
            Text(updateStyledInline(text, size: 11))
                .foregroundColor(TLPalette.textPrimary)
        }
    }

    private func quote(_ text: String) -> some View {
        Text(updateStyledInline(text, size: 11, italic: true))
            .foregroundColor(TLPalette.textSecondary)
    }
}

// MARK: - 업데이트 사용 가능 시트

/// 설정 .sheet와 메뉴바 NSWindow가 공유하는 업데이트 안내 시트.
/// - onClose == nil → 설정 경로 (.sheet dismiss)
/// - onClose 전달 → 메뉴바 경로 (전용 NSWindow를 직접 닫음)
struct UpdateAvailableSheet: View {
    let update: (tag: String, htmlURL: String, notes: String)
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var currentVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var newVersionText: String {
        let normalized = update.tag.replacingOccurrences(of: "^v", with: "", options: .regularExpression)
        return "v\(normalized)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.xl) {
            HStack(spacing: TLSpace.sm) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(TLPalette.upload)
                Text(Localized.updateAvailableTitle(newVersionText))
                    .font(.headline)
            }
            Divider()

            VStack(alignment: .leading, spacing: TLSpace.sm) {
                versionRow(label: Localized.currentVersion, value: "v\(currentVersionText)")
                versionRow(label: Localized.updateNewVersion, value: newVersionText)
            }

            Text(Localized.updateNotes)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textSecondary)
            ReleaseNotesView(markdown: update.notes)
                .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
                .frame(height: 200)

            VStack(alignment: .leading, spacing: TLSpace.xs) {
                Text(Localized.updateMethodTitle)
                    .font(TLFont.smallBold)
                    .foregroundColor(TLPalette.textSecondary)
                Text(Localized.updateMethodBody)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                Spacer()
                Button(Localized.close) {
                    onClose?() ?? dismiss()
                }
                .buttonStyle(.bordered)
                Button(Localized.updateDownloadButton) {
                    if let url = URL(string: update.htmlURL) {
                        NSWorkspace.shared.open(url)
                    }
                    onClose?() ?? dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(TLSpace.xl)
        .frame(width: 440)
    }

    private func versionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(TLFont.detail)
                .foregroundColor(TLPalette.textSecondary)
            Spacer()
            Text(value)
                .font(TLFont.detail.monospacedDigit())
                .foregroundColor(TLPalette.textPrimary)
        }
    }
}