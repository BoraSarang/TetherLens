import SwiftUI

/// 네트워크 진단 센터 패널 뷰.
struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [DiagnosticsEntry] = []
    @State private var isRunning = false
    @State private var hostInput = "8.8.8.8"

    private let diagnostics = NetworkDiagnostics.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("네트워크 진단")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("전체 실행") { runAll() }
                    .disabled(isRunning)
                Button("닫기") { dismiss() }
            }

            Divider()

            HStack {
                Text("호스트")
                TextField("8.8.8.8 또는 도메인", text: $hostInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            if isRunning {
                ProgressView("진단 실행 중…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(entry.status.symbol) \(entry.title)")
                                    .font(.callout.weight(.semibold))
                                Spacer()
                                Text(entry.status.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(statusColor(entry.status))
                            }
                            Text(entry.detail)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: TLRound.medium).fill(Color.gray.opacity(0.1)))
                    }
                }
            }

            if !entries.isEmpty {
                HStack {
                    Button("Markdown 리포트 복사") { copyMarkdown() }
                    Spacer()
                    Text("\(entries.count)개 항목")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 460)
        .onAppear { runAll() }
    }

    private func statusColor(_ status: DiagnosticsStatus) -> Color {
        switch status {
        case .ok: .green
        case .warn: .orange
        case .fail: .red
        }
    }

    private func runAll() {
        guard !isRunning else { return }
        isRunning = true
        entries = []
        let host = hostInput.trimmingCharacters(in: .whitespaces)

        Task {
            let proxy = await diagnostics.proxyCheck()
            let dns = await diagnostics.dnsLeakCheck()
            let ping = await diagnostics.customPing(host: host)
            let trace = await diagnostics.traceroute(host: host)
            let bloat = await diagnostics.bufferbloat()
            entries = [proxy, dns, ping, trace, bloat]
            isRunning = false
        }
    }

    private func copyMarkdown() {
        let doc = diagnostics.renderMarkdown(entries)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(doc, forType: .string)
    }
}