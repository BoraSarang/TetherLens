import SwiftUI

struct AboutView: View {
    let onClose: () -> Void

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("TetherLens")
                .font(.title2.bold())

            Text("버전 \(version) (\(build))")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 6) {
                Text("macOS 핫스팟/테더링 데이터 사용량 모니터")
                    .font(.caption)
                    .foregroundColor(.secondary)

                detailRow(label: "제작", value: "OkStart")

                Button("okstart@gmail.com") {
                    NSWorkspace.shared.open(URL(string: "mailto:okstart@gmail.com")!)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.blue)
                .underline()

                Button("☕️ 후원하기") {
                    NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/okstart")!)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
                .padding(.top, 4)
            }

            Spacer()

            Button("닫기") { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(24)
        .padding(.bottom, 12)
        .frame(width: 240, height: 340)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}
