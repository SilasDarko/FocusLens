import Foundation
import Combine
import SwiftUI

/// Drives both the SessionSetupView and the ActiveSessionView.
/// Manages the lifecycle of a single in-progress study session.
@MainActor
final class SessionViewModel: ObservableObject {

    // MARK: - Session Setup State

    @Published var subject: String = ""
    @Published var goal: String = ""
    @Published var plannedDurationMinutes: Int = 45
    @Published var environment: EnvironmentType = .quiet
    @Published var energyLevel: EnergyLevel = .medium
    @Published var distractionLevelBefore: DistractionLevel = .low
    @Published var accessibilityNotes: String = ""

    // MARK: - Active Session State

    @Published private(set) var activeSession: StudySession?
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var isSessionActive: Bool = false
    @Published var latestPrediction: FocusPrediction?
    @Published var showPredictionResult: Bool = false

    // MARK: - Checkpoint Input State

    @Published var checkpointFocusRating: Int = 3
    @Published var checkpointInterruptionCount: Int = 0
    @Published var checkpointSwitchedApp: Bool = false
    @Published var checkpointDifficulty: Int = 3
    @Published var checkpointStress: Int = 2

    // MARK: - Validation

    var canStartSession: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !goal.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Timer

    private var timerTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let storage: LocalStorageService
    private let predictor: FocusPredictionService

    init(
        storage: LocalStorageService = .shared,
        predictor: FocusPredictionService = .shared
    ) {
        self.storage = storage
        self.predictor = predictor
    }

    // MARK: - Session Lifecycle

    func startSession() {
        guard canStartSession else { return }
        let session = StudySession(
            subject: subject,
            goal: goal,
            plannedDurationMinutes: plannedDurationMinutes,
            environment: environment,
            energyLevel: energyLevel,
            distractionLevelBefore: distractionLevelBefore,
            accessibilityNotes: accessibilityNotes
        )
        activeSession = session
        isSessionActive = true
        elapsedSeconds = 0
        storage.upsert(session: session)
        startTimer()
    }

    func endSession() {
        stopTimer()
        guard var session = activeSession else { return }
        session.endDate = Date()

        if let prediction = predictor.predict(for: session) {
            session.prediction = prediction
            latestPrediction = prediction
        }

        storage.upsert(session: session)
        activeSession = session
        isSessionActive = false
        showPredictionResult = true
    }

    func logCheckpoint() {
        guard isSessionActive else { return }
        let checkpoint = FocusCheckpoint(
            focusRating: checkpointFocusRating,
            interruptionCount: checkpointInterruptionCount,
            switchedAppOrTask: checkpointSwitchedApp,
            perceivedDifficulty: checkpointDifficulty,
            stressLevel: checkpointStress
        )
        activeSession?.checkpoints.append(checkpoint)
        if let session = activeSession {
            storage.upsert(session: session)
        }
        resetCheckpointInputs()
    }

    // MARK: - Timer Management

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                self.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Derived Display Helpers

    var progressFraction: Double {
        let total = Double(plannedDurationMinutes * 60)
        guard total > 0 else { return 0 }
        return min(Double(elapsedSeconds) / total, 1.0)
    }

    var elapsedTimeFormatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var plannedDurationFormatted: String {
        "\(plannedDurationMinutes) min"
    }

    var checkpointCount: Int {
        activeSession?.checkpoints.count ?? 0
    }

    // MARK: - Private Helpers

    private func resetCheckpointInputs() {
        checkpointFocusRating = 3
        checkpointInterruptionCount = 0
        checkpointSwitchedApp = false
        checkpointDifficulty = 3
        checkpointStress = 2
    }
}
