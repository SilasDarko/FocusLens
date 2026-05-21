import Foundation

// MARK: - Enumerations

enum EnvironmentType: String, Codable, CaseIterable, Identifiable {
    case quiet = "Quiet"
    case noisy = "Noisy"
    case sharedSpace = "Shared Space"
    case library = "Library"
    case dorm = "Dorm"
    case outdoors = "Outdoors"

    var id: String { rawValue }

    /// Numeric encoding used as a feature for ML inference.
    var featureValue: Double {
        switch self {
        case .quiet:       return 0.0
        case .library:     return 1.0
        case .dorm:        return 2.0
        case .sharedSpace: return 3.0
        case .outdoors:    return 4.0
        case .noisy:       return 5.0
        }
    }
}

enum EnergyLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var featureValue: Double {
        switch self {
        case .low:    return 0.0
        case .medium: return 1.0
        case .high:   return 2.0
        }
    }
}

enum DistractionLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var featureValue: Double {
        switch self {
        case .low:    return 0.0
        case .medium: return 1.0
        case .high:   return 2.0
        }
    }
}

// MARK: - StudySession

/// The primary model representing a single study session.
/// All data is local — nothing is transmitted off device.
struct StudySession: Codable, Identifiable {
    var id: UUID
    var subject: String
    var goal: String
    var plannedDurationMinutes: Int
    var environment: EnvironmentType
    var energyLevel: EnergyLevel
    var distractionLevelBefore: DistractionLevel
    var accessibilityNotes: String
    var startDate: Date
    var endDate: Date?
    var checkpoints: [FocusCheckpoint]
    var prediction: FocusPrediction?

    init(
        id: UUID = UUID(),
        subject: String,
        goal: String,
        plannedDurationMinutes: Int,
        environment: EnvironmentType,
        energyLevel: EnergyLevel,
        distractionLevelBefore: DistractionLevel,
        accessibilityNotes: String = "",
        startDate: Date = Date(),
        endDate: Date? = nil,
        checkpoints: [FocusCheckpoint] = [],
        prediction: FocusPrediction? = nil
    ) {
        self.id = id
        self.subject = subject
        self.goal = goal
        self.plannedDurationMinutes = plannedDurationMinutes
        self.environment = environment
        self.energyLevel = energyLevel
        self.distractionLevelBefore = distractionLevelBefore
        self.accessibilityNotes = accessibilityNotes
        self.startDate = startDate
        self.endDate = endDate
        self.checkpoints = checkpoints
        self.prediction = prediction
    }

    // MARK: Derived helpers

    var actualDurationMinutes: Int? {
        guard let end = endDate else { return nil }
        return Int(end.timeIntervalSince(startDate) / 60)
    }

    var isComplete: Bool { endDate != nil }

    var averageFocusRating: Double? {
        guard !checkpoints.isEmpty else { return nil }
        let sum = checkpoints.reduce(0.0) { $0 + Double($1.focusRating) }
        return sum / Double(checkpoints.count)
    }

    var totalInterruptions: Int {
        checkpoints.reduce(0) { $0 + $1.interruptionCount }
    }

    var totalAppSwitches: Int {
        checkpoints.reduce(0) { $0 + ($1.switchedAppOrTask ? 1 : 0) }
    }

    var averageStress: Double? {
        guard !checkpoints.isEmpty else { return nil }
        let sum = checkpoints.reduce(0.0) { $0 + Double($1.stressLevel) }
        return sum / Double(checkpoints.count)
    }

    var averageDifficulty: Double? {
        guard !checkpoints.isEmpty else { return nil }
        let sum = checkpoints.reduce(0.0) { $0 + Double($1.perceivedDifficulty) }
        return sum / Double(checkpoints.count)
    }
}
