import SwiftUI

/// Displays the local history of completed study sessions.
/// Users can view session details or delete sessions from this screen.
struct HistoryView: View {

    @StateObject private var viewModel = HistoryViewModel()
    @State private var sessionToDelete: StudySession?
    @State private var showDeleteAllAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.sessions.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteAllAlert = true
                            } label: {
                                Label("Delete All Sessions", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("History options menu")
                    }
                }
            }
            .alert("Delete All Sessions?", isPresented: $showDeleteAllAlert) {
                Button("Delete All", role: .destructive) { viewModel.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes all local session history. This cannot be undone.")
            }
            .onAppear { viewModel.loadSessions() }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            ForEach(viewModel.sessions) { session in
                NavigationLink(destination: sessionDetail(session: session)) {
                    SessionHistoryRow(session: session, viewModel: viewModel)
                }
            }
            .onDelete { offsets in
                viewModel.delete(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Session Detail

    @ViewBuilder
    private func sessionDetail(session: StudySession) -> some View {
        if let prediction = session.prediction {
            PredictionResultView(session: session)
                .environmentObject(AccessibilitySettingsService.shared)
        } else {
            SessionDetailFallbackView(session: session)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Sessions Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Complete a study session to see your history here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let session: StudySession
    let viewModel: HistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.subject)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if let prediction = session.prediction {
                    categoryBadge(prediction.category)
                }
            }

            Text(session.goal)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                Label(viewModel.formattedDate(for: session), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(viewModel.durationText(for: session), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let prediction = session.prediction {
                    Label("\(prediction.confidencePercent)%", systemImage: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let friction = viewModel.keyFrictionPoint(for: session)
            if friction != "None identified" && friction != "No checkpoints logged" {
                Label(friction, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [session.subject, session.goal]
        if let pred = session.prediction {
            parts.append(pred.category.rawValue)
            parts.append("\(pred.confidencePercent)% confidence")
        }
        parts.append(viewModel.durationText(for: session))
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func categoryBadge(_ category: FocusCategory) -> some View {
        Text(category.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(categoryColor(category).opacity(0.15))
            .foregroundStyle(categoryColor(category))
            .clipShape(Capsule())
    }

    private func categoryColor(_ category: FocusCategory) -> Color {
        switch category {
        case .deepFocus:      return .green
        case .mixedFocus:     return .yellow
        case .distracted:     return .orange
        case .recoveryNeeded: return .red
        }
    }
}

// MARK: - Session Detail Fallback

struct SessionDetailFallbackView: View {
    let session: StudySession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.subject)
                        .font(.title2).fontWeight(.bold)
                    Text(session.goal)
                        .font(.body).foregroundStyle(.secondary)
                }

                if session.checkpoints.isEmpty {
                    Text("No checkpoints were logged during this session, so no prediction was generated.")
                        .foregroundStyle(.secondary)
                }

                ForEach(session.checkpoints) { checkpoint in
                    CheckpointSummaryRow(checkpoint: checkpoint)
                }
            }
            .padding(20)
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CheckpointSummaryRow: View {
    let checkpoint: FocusCheckpoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(checkpoint.timestamp, style: .time)
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label("Focus \(checkpoint.focusRating)/5", systemImage: "brain")
                Label("Stress \(checkpoint.stressLevel)/5", systemImage: "bolt")
                Label("\(checkpoint.interruptionCount) int.", systemImage: "bell")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}
