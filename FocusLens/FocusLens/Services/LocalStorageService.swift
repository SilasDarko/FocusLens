import Foundation

/// Persists and retrieves study sessions using JSON stored in the app's
/// Documents directory. This keeps all data local and avoids any cloud
/// sync dependency, which aligns with the privacy-first design of FocusLens.
final class LocalStorageService {

    static let shared = LocalStorageService()

    private let fileName = "focus_sessions.json"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Load

    func loadSessions() -> [StudySession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([StudySession].self, from: data)
        } catch {
            print("[LocalStorageService] Failed to load sessions: \(error)")
            return []
        }
    }

    // MARK: - Save

    @discardableResult
    func save(sessions: [StudySession]) -> Bool {
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
            return true
        } catch {
            print("[LocalStorageService] Failed to save sessions: \(error)")
            return false
        }
    }

    // MARK: - Upsert

    /// Insert a new session or update an existing one (matched by id).
    @discardableResult
    func upsert(session: StudySession) -> Bool {
        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        return save(sessions: sessions)
    }

    // MARK: - Delete

    @discardableResult
    func delete(sessionID: UUID) -> Bool {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == sessionID }
        return save(sessions: sessions)
    }

    /// Permanently removes all session data from disk.
    /// Called when the user chooses "Delete all history" in settings.
    @discardableResult
    func deleteAllSessions() -> Bool {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            return true
        } catch {
            print("[LocalStorageService] Failed to delete all sessions: \(error)")
            return false
        }
    }
}
