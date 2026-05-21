import Combine
import Foundation
import SwiftUI

/// Stores and exposes user-defined accessibility preferences.
/// These are persisted via UserDefaults and applied app-wide via the environment.
final class AccessibilitySettingsService: ObservableObject {

    static let shared = AccessibilitySettingsService()

    // MARK: - Published preferences

    @Published var reducedMotion: Bool
    @Published var lowVisualClutter: Bool
    @Published var highContrast: Bool

    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let reducedMotion = "accessibility.reducedMotion"
        static let lowVisualClutter = "accessibility.lowVisualClutter"
        static let highContrast = "accessibility.highContrast"
    }

    private init() {
        self.reducedMotion    = UserDefaults.standard.bool(forKey: Keys.reducedMotion)
        self.lowVisualClutter = UserDefaults.standard.bool(forKey: Keys.lowVisualClutter)
        self.highContrast     = UserDefaults.standard.bool(forKey: Keys.highContrast)

        $reducedMotion
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: Keys.reducedMotion) }
            .store(in: &cancellables)

        $lowVisualClutter
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: Keys.lowVisualClutter) }
            .store(in: &cancellables)

        $highContrast
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: Keys.highContrast) }
            .store(in: &cancellables)
    }

    // MARK: - Derived helpers

    /// Returns the appropriate animation to use throughout the app.
    /// When reducedMotion is enabled, returns nil so callers can skip animations.
    var preferredAnimation: Animation? {
        reducedMotion ? nil : .easeInOut(duration: 0.25)
    }

    /// Background color adjusted for high-contrast mode.
    var adaptiveBackground: Color {
        highContrast ? Color(.systemBackground) : Color(.secondarySystemBackground)
    }
}
