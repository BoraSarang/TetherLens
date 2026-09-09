import SwiftUI

/// 네트워크 진단 센터 패널 뷰.
struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [DiagnosticsEntry] = []
    @State private var isRunning = false
    @State private var hostInput = "8.8.8.8"
    @State private var speedRunning = false
    @State private var speedArmed = false  // 유료망 경고 확인 후 2차 탭에 실행

    private let diagnostics = NetworkDiagnostics.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("네트워크 진단")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("속도 테스트") { runSpeedTest() }
                    .disabled(isRunning || speedRunning)
                Button("전체 실행") { runAll() }
                    .disabled(isRunning)
                Button("닫기") { dismiss() }
            }

            if speedArmed {
                Text("유료/제한망 연결 — 약 15MB 소모. 다시 눌러 시작")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            HStack {
                Text("호스트")
                TextField("8.8.8.8 또는 도메인", text: $hostInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            if isRunning || speedRunning {
                ProgressView(speedRunning ? "속도 측정 중… (약 15MB)" : "진단 실행 중…")
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

    private func runSpeedTest() {
        guard !isRunning, !speedRunning else { return }
        Task {
            // 유료망이면 1차 탭에 경고만, 2차 탭에 실행 (데이터 소모 통제)
            if !speedArmed, await diagnostics.isCurrentPathExpensive() {
                speedArmed = true
                return
            }
            speedArmed = false
            speedRunning = true
            defer { speedRunning = false }
            let entry = await diagnostics.speedTest()
            entries.append(entry)
        }
    }

    private func copyMarkdown() {
        let doc = diagnostics.renderMarkdown(entries)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(doc, forType: .string)
    }
}