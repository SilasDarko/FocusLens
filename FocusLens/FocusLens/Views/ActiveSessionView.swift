import SwiftUI

/// Displayed while a study session is in progress.
/// Provides the timer, checkpoint logging, and session end controls.
struct ActiveSessionView: View {

    @ObservedObject var viewModel: SessionViewModel
    @State private var showCheckpointSheet = false
    @State private var showEndConfirmation = false
    @EnvironmentObject private var accessibility: AccessibilitySettingsService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    sessionHeaderCard
                    timerSection
                    checkpointCountCard
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle(viewModel.activeSession?.subject ?? "Session")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showCheckpointSheet) {
                CheckpointInputSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .alert("End Session?", isPresented: $showEndConfirmation) {
                Button("End & Predict", role: .destructive) {
                    viewModel.endSession()
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("This will stop the timer and generate your on-device focus prediction.")
            }
        }
    }

    // MARK: - Session Header

    private var sessionHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session = viewModel.activeSession {
                Label(session.goal, systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityLabel("Session goal: \(session.goal)")

                HStack(spacing: 16) {
                    TagPill(text: session.environment.rawValue, systemImage: "location")
                    TagPill(text: session.energyLevel.rawValue, systemImage: "bolt")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Timer

    private var timerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: viewModel.progressFraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(accessibility.reducedMotion ? nil : .linear(duration: 1.0), value: viewModel.progressFraction)

                VStack(spacing: 4) {
                    Text(viewModel.elapsedTimeFormatted)
                        .font(.system(size: 40, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Elapsed time: \(viewModel.elapsedTimeFormatted)")

                    Text("of \(viewModel.plannedDurationFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)
            .padding(.vertical, 8)

            if viewModel.progressFraction >= 1.0 {
                    Text("Planned duration reached")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .fontWeight(.medium)
                        .accessibilityLabel("Planned study duration has been reached")
            }
        }
    }

    // MARK: - Checkpoint Count

    private var checkpointCountCard: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .accessibilityHidden(true)

            Text("^[\(viewModel.checkpointCount) checkpoint](inflect: true) logged")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("\(viewModel.checkpointCount) checkpoints logged")
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button(action: { showCheckpointSheet = true }) {
                Label("Log Checkpoint", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Log a study checkpoint")
            .accessibilityHint("Opens a form to record your current focus state")

            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                Text("End Session")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .font(.headline)
                    .foregroundStyle(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                    )
            }
            .accessibilityLabel("End study session and generate prediction")
        }
    }
}

// MARK: - Checkpoint Input Sheet

struct CheckpointInputSheet: View {

    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RatingRow(label: "Focus Level", value: $viewModel.checkpointFocusRating, lowLabel: "Low", highLabel: "High")
                    RatingRow(label: "Stress Level", value: $viewModel.checkpointStress, lowLabel: "Calm", highLabel: "Stressed")
                    RatingRow(label: "Difficulty", value: $viewModel.checkpointDifficulty, lowLabel: "Easy", highLabel: "Hard")
                } header: {
                    Text("Self Ratings (1–5)")
                }

                Section {
                    Stepper(value: $viewModel.checkpointInterruptionCount, in: 0...20) {
                        HStack {
                            Text("Interruptions")
                            Spacer()
                            Text("\(viewModel.checkpointInterruptionCount)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityLabel("Number of interruptions: \(viewModel.checkpointInterruptionCount)")

                    Toggle("Switched App or Task", isOn: $viewModel.checkpointSwitchedApp)
                        .accessibilityLabel("Did you switch apps or tasks? \(viewModel.checkpointSwitchedApp ? "Yes" : "No")")
                } header: {
                    Text("Activity")
                }

                Section {
                    Button(action: saveCheckpoint) {
                        HStack {
                            Spacer()
                            Text("Save Checkpoint")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Save this checkpoint")
                }
            }
            .navigationTitle("Log Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveCheckpoint() {
        viewModel.logCheckpoint()
        dismiss()
    }
}

// MARK: - RatingRow

/// 1–5 star rating row with low/high endpoint labels.
struct RatingRow: View {
    let label: String
    @Binding var value: Int
    let lowLabel: String
    let highLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value)/5")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                Text(lowLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { index in
                        Button(action: { value = index }) {
                            Image(systemName: index <= value ? "circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(index <= value ? Color.accentColor : Color(.systemGray4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(label): \(index)")
                        .accessibilityAddTraits(index == value ? .isSelected : [])
                    }
                }

                Text(highLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) out of 5")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(5, value + 1)
            case .decrement: value = max(1, value - 1)
            @unknown default: break
            }
        }
    }
}

// MARK: - TagPill

struct TagPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemBackground))
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    ActiveSessionView(viewModel: {
        let vm = SessionViewModel()
        vm.subject = "Physics"
        vm.goal = "Review wave mechanics"
        vm.plannedDurationMinutes = 50
        return vm
    }())
    .environmentObject(AccessibilitySettingsService.shared)
}
