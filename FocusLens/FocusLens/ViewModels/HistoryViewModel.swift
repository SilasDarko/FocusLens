import Foundation
import Combine

/// Provides the list of completed sessions for HistoryView.
@MainActor
final class HistoryViewModel: ObservableObject {

    @Published private(set) var sessions: [StudySession] = []
    @Published var showDeleteAllConfirmation: Bool = false

    private let storage: LocalStorageService

    init(storage: LocalStorageService = .shared) {
        self.storage = storage
    }

    // MARK: - Data Loading

    func loadSessions() {
        sessions = storage.loadSessions()
            .filter { $0.isComplete }
            .sorted { ($0.endDate ?? $0.startDate) > ($1.endDate ?? $1.startDate) }
    }

    // MARK: - Deletion

    func delete(session: StudySession) {
        storage.delete(sessionID: session.id)
        sessions.removeAll { $0.id == session.id }
    }

    func deleteAll() {
        storage.deleteAllSessions()
        sessions = []
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { sessions[$0] }
        for session in toDelete {
            storage.delete(sessionID: session.id)
        }
        for index in offsets.sorted(by: >) {
            sessions.remove(at: index)
        }
    }

    // MARK: - Display Helpers

    func formattedDate(for session: StudySession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.startDate)
    }

    func durationText(for session: StudySession) -> String {
        guard let minutes = session.actualDurationMinutes else { return "—" }
        return "\(minutes) min"
    }

    func keyFrictionPoint(for session: StudySession) -> String {
        guard !session.checkpoints.isEmpty else { return "No checkpoints logged" }
        let interruptions = session.totalInterruptions
        let switches = session.totalAppSwitches
        let avgStress = session.averageStress ?? 0

        if interruptions >= 5 { return "High interruptions (\(interruptions))" }
        if switches >= 3 { return "Frequent task switching (\(switches))" }
        if avgStress >= 4 { return "Elevated stress" }
        return "None identified"
    }
}
