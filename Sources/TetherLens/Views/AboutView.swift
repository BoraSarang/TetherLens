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
        VStack(spacing: TLSpace.xxl) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("TetherLens")
                .font(.title2.bold())

            Text(Localized.version(version, build))
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textSecondary)

            Divider()

            VStack(spacing: TLSpace.sm) {
                Text(Localized.appDescription)
                    .font(TLFont.caption)
                    .foregroundColor(TLPalette.textSecondary)

                detailRow(label: Localized.createdBy, value: "BoRaSaRang")

                Button("leeborasarang@gmail.com") {
                    NSWorkspace.shared.open(URL(string: "mailto:leeborasarang@gmail.com")!)
                }
                .buttonStyle(.plain)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.accent)
                .underline()
            }

            Spacer()

            Button(Localized.close) { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(24)
        .padding(.bottom, TLSpace.xl)
        .frame(width: TLSize.aboutSheet, height: 340)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: TLSpace.xs) {
            Text(label)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textSecondary)
            Text(value)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textPrimary)
        }
    }
}
