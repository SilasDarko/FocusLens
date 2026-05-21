import Foundation

// MARK: - Focus Category

/// The four output labels for the on-device classifier.
/// These are intentionally study-oriented — not clinical or diagnostic.
enum FocusCategory: String, Codable, CaseIterable, Identifiable {
    case deepFocus = "Deep Focus"
    case mixedFocus = "Mixed Focus"
    case distracted = "Distracted"
    case recoveryNeeded = "Recovery Needed"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .deepFocus:       return "brain.head.profile"
        case .mixedFocus:      return "arrow.triangle.2.circlepath"
        case .distracted:      return "exclamationmark.bubble"
        case .recoveryNeeded:  return "battery.25"
        }
    }

    var accentColorName: String {
        switch self {
        case .deepFocus:       return "FocusGreen"
        case .mixedFocus:      return "FocusYellow"
        case .distracted:      return "FocusOrange"
        case .recoveryNeeded:  return "FocusRed"
        }
    }

    /// Short reflection prompt shown on the result screen.
    /// Phrasing avoids any medical or diagnostic tone.
    var reflectionPrompt: String {
        switch self {
        case .deepFocus:
            return "Strong session. Consider keeping a note of what worked so you can recreate it."
        case .mixedFocus:
            return "Solid effort with some variation. Shorter sprints or a quieter setting might help sharpen focus next time."
        case .distracted:
            return "Distractions were a factor today. Try breaking the next session into smaller chunks with explicit break points."
        case .recoveryNeeded:
            return "It looks like you may have been running low on capacity. Rest and a lighter start next session could help."
        }
    }
}

// MARK: - Session Features

/// The feature vector extracted from a completed session.
/// This struct is the bridge between raw session data and the ML model input.
struct SessionFeatures {
    let plannedDurationMinutes: Double
    let checkpointCount: Double
    let averageFocusRating: Double
    let totalInterruptions: Double
    let appSwitchCount: Double
    let energyLevel: Double          // 0 = low, 1 = medium, 2 = high
    let distractionLevelBefore: Double // 0 = low, 1 = medium, 2 = high
    let averageStress: Double
    let averageDifficulty: Double
    let environmentType: Double      // encoded per EnvironmentType.featureValue

    /// Build features from a completed session. Returns nil if the session has
    /// no checkpoints (prediction would be meaningless without any data).
    static func build(from session: StudySession) -> SessionFeatures? {
        guard !session.checkpoints.isEmpty else { return nil }
        return SessionFeatures(
            plannedDurationMinutes: Double(session.plannedDurationMinutes),
            checkpointCount:        Double(session.checkpoints.count),
            averageFocusRating:     session.averageFocusRating ?? 3.0,
            totalInterruptions:     Double(session.totalInterruptions),
            appSwitchCount:         Double(session.totalAppSwitches),
            energyLevel:            session.energyLevel.featureValue,
            distractionLevelBefore: session.distractionLevelBefore.featureValue,
            averageStress:          session.averageStress ?? 2.5,
            averageDifficulty:      session.averageDifficulty ?? 2.5,
            environmentType:        session.environment.featureValue
        )
    }
}

// MARK: - Contributing Factor

/// A human-readable explanation of what drove a prediction.
struct ContributingFactor: Identifiable {
    var id = UUID()
    let label: String
    let detail: String
}

// MARK: - Focus Prediction

/// The on-device prediction result stored alongside a session.
struct FocusPrediction: Codable, Identifiable {
    var id: UUID
    var category: FocusCategory
    /// Value between 0 and 1, where 1 is 100% confidence.
    var confidence: Double
    /// Plain-text explanation of contributing factors (stored for history display).
    var factorSummary: String
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        category: FocusCategory,
        confidence: Double,
        factorSummary: String,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.confidence = confidence.clamped(to: 0...1)
        self.factorSummary = factorSummary
        self.generatedAt = generatedAt
    }

    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

// MARK: - Double clamp helper

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
