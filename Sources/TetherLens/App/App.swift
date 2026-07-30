import SwiftUI

@main
struct TetherLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasShownOnboarding") private var hasShownOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        Settings {
            EmptyView()
                .onAppear {
                    if !hasShownOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView {
                        hasShownOnboarding = true
                        showOnboarding = false
                    }
                }
        }
    }
}
