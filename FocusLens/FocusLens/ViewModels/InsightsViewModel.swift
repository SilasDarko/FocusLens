import Combine
import Foundation

/// Computes deterministic local insights from past session data.
/// All calculations run on-device from locally stored sessions.
@MainActor
final class InsightsViewModel: ObservableObject {

    @Published private(set) var mostCommonCategory: FocusCategory?
    @Published private(set) var averageInterruptionsPerSession: Double = 0
    @Published private(set) var bestEnvironment: EnvironmentType?
    @Published private(set) var recentTrend: [TrendPoint] = []
    @Published private(set) var totalSessionCount: Int = 0
    @Published private(set) var hasEnoughData: Bool = false

    private let storage: LocalStorageService
    private let minimumSessionsForInsights = 2

    init(storage: LocalStorageService = .shared) {
        self.storage = storage
    }

    // MARK: - Data computation

    func computeInsights() {
        let sessions = storage.loadSessions()
            .filter { $0.isComplete && $0.prediction != nil }
            .sorted { $0.startDate < $1.startDate }

        totalSessionCount = sessions.count
        hasEnoughData = sessions.count >= minimumSessionsForInsights

        guard hasEnoughData else { return }

        mostCommonCategory = computeMostCommon(sessions: sessions)
        averageInterruptionsPerSession = computeAverageInterruptions(sessions: sessions)
        bestEnvironment = computeBestEnvironment(sessions: sessions)
        recentTrend = computeTrend(sessions: sessions)
    }

    // MARK: - Private calculations

    private func computeMostCommon(sessions: [StudySession]) -> FocusCategory? {
        var counts: [FocusCategory: Int] = [:]
        for session in sessions {
            if let cat = session.prediction?.category {
                counts[cat, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func computeAverageInterruptions(sessions: [StudySession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + $1.totalInterruptions }
        return Double(total) / Double(sessions.count)
    }

    /// Identifies the environment most associated with Deep Focus or Mixed Focus outcomes.
    private func computeBestEnvironment(sessions: [StudySession]) -> EnvironmentType? {
        var scores: [EnvironmentType: Double] = [:]
        var counts: [EnvironmentType: Int] = [:]

        for session in sessions {
            guard let category = session.prediction?.category else { continue }
            let score: Double
            switch category {
            case .deepFocus:       score = 2.0
            case .mixedFocus:      score = 1.0
            case .distracted:      score = 0.0
            case .recoveryNeeded:  score = -0.5
            }
            scores[session.environment, default: 0] += score
            counts[session.environment, default: 0] += 1
        }

        // Normalise by session count per environment to avoid sample size bias
        let normalised: [EnvironmentType: Double] = scores.compactMapValues { rawScore in
            let env = scores.first(where: { $0.value == rawScore })?.key
            guard let env, let count = counts[env], count > 0 else { return nil }
            return rawScore / Double(count)
        }
        let best = normalised.max(by: { $0.value < $1.value })
        let result = best.flatMap { _ in scores.first(where: { $0.value == $0.value })?.key }
        return result ?? scores.keys.first
    }

    /// Returns trend points for the chart: each point is a session with a numeric focus score.
    private func computeTrend(sessions: [StudySession]) -> [TrendPoint] {
        let recent = sessions.suffix(10)
        return recent.enumerated().compactMap { index, session in
            guard let avg = session.averageFocusRating else { return nil }
            return TrendPoint(index: index, date: session.startDate, focusScore: avg, subject: session.subject)
        }
    }
}

// MARK: - Supporting types

struct TrendPoint: Identifiable {
    var id = UUID()
    let index: Int
    let date: Date
    let focusScore: Double   // average self-rated focus 1-5
    let subject: String

    var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: date)
    }
}
