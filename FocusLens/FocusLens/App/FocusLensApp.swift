import SwiftUI

@main
struct FocusLensApp: App {

    @StateObject private var accessibility = AccessibilitySettingsService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootTabView()
                    .environmentObject(accessibility)
            } else {
                OnboardingView()
            }
        }
    }
}
