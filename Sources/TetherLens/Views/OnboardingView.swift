import SwiftUI

struct OnboardingView: View {
  let onComplete: @MainActor () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 64, height: 64)

      Text(Localized.welcomeTitle)
        .font(.title2.bold())

      Text(Localized.welcomeDescription)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Divider()

      VStack(alignment: .leading, spacing: 12) {
        OnboardingRow(
          icon: "location.fill",
          title: Localized.locationPermissionTitle,
          description: Localized.locationPermissionDescription
        )
        OnboardingRow(
          icon: "bell.fill",
          title: Localized.notificationPermissionTitle,
          description: Localized.notificationPermissionDescription
        )
      }
      .padding(.horizontal, 32)

      Spacer()

      Button(Localized.getStarted) {
        onComplete()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

      Spacer()
    }
    .frame(width: 340, height: 420)
  }
}

private struct OnboardingRow: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(.accentColor)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.body.bold())
        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
