import Foundation

/// A single in-session checkpoint logged by the student.
/// All values are self-reported, reinforcing the privacy-first model —
/// no passive sensor data is collected.
struct FocusCheckpoint: Codable, Identifiable {
    var id: UUID
    var timestamp: Date

    /// Self-rated focus: 1 (very low) – 5 (very high)
    var focusRating: Int

    /// Number of interruptions (people, notifications, etc.) since last checkpoint
    var interruptionCount: Int

    /// Whether the student switched apps or tasks since last checkpoint
    var switchedAppOrTask: Bool

    /// Perceived difficulty of the material: 1 (very easy) – 5 (very hard)
    var perceivedDifficulty: Int

    /// Self-rated stress level: 1 (calm) – 5 (very stressed)
    var stressLevel: Int

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        focusRating: Int,
        interruptionCount: Int,
        switchedAppOrTask: Bool,
        perceivedDifficulty: Int,
        stressLevel: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.focusRating = focusRating.clamped(to: 1...5)
        self.interruptionCount = max(0, interruptionCount)
        self.switchedAppOrTask = switchedAppOrTask
        self.perceivedDifficulty = perceivedDifficulty.clamped(to: 1...5)
        self.stressLevel = stressLevel.clamped(to: 1...5)
    }
}

// MARK: - Comparable extension for Int clamping

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
