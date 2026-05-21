import SwiftUI

/// Displays the on-device focus prediction result after a session ends.
/// Shows the category, confidence score, contributing factors, and a reflection prompt.
struct PredictionResultView: View {

    let session: StudySession
    @EnvironmentObject private var accessibility: AccessibilitySettingsService
    @Environment(\.dismiss) private var dismiss

    private var prediction: FocusPrediction? { session.prediction }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if let prediction {
                        categoryHeader(prediction: prediction)
                        confidenceMeter(prediction: prediction)
                        contributingFactorsSection(session: session, prediction: prediction)
                        reflectionSection(prediction: prediction)
                    } else {
                        noPredictionPlaceholder
                    }

                    sessionSummarySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Session Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close prediction result")
                }
            }
        }
    }

    // MARK: - Category Header

    @ViewBuilder
    private func categoryHeader(prediction: FocusPrediction) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: prediction.category.systemImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(prediction.category.rawValue)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Predicted Focus Category")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Predicted focus category: \(prediction.category.rawValue)")
    }

    // MARK: - Confidence Meter

    @ViewBuilder
    private func confidenceMeter(prediction: FocusPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Model Confidence")
                    .font(.headline)
                Spacer()
                Text("\(prediction.confidencePercent)%")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 10)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * prediction.confidence, height: 10)
                        .animation(accessibility.reducedMotion ? nil : .easeOut(duration: 0.6), value: prediction.confidence)
                }
            }
            .frame(height: 10)

            Text("Confidence reflects how closely this session's pattern matched the training examples. It does not indicate medical or clinical certainty.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Model confidence: \(prediction.confidencePercent) percent")
    }

    // MARK: - Contributing Factors

    @ViewBuilder
    private func contributingFactorsSection(session: StudySession, prediction: FocusPrediction) -> some View {
        let factors = FocusPredictionService.shared.explainPrediction(
            category: prediction.category,
            features: SessionFeatures.build(from: session) ?? placeholderFeatures
        )

        VStack(alignment: .leading, spacing: 14) {
            Text("Contributing Factors")
                .font(.headline)

            ForEach(factors) { factor in
                FactorRow(factor: factor)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Reflection

    @ViewBuilder
    private func reflectionSection(prediction: FocusPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reflection", systemImage: "lightbulb")
                .font(.headline)
                .accessibilityHidden(true)

            Text(prediction.category.reflectionPrompt)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This is a suggestion, not a recommendation. You know your study patterns best.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reflection: \(prediction.category.reflectionPrompt)")
    }

    // MARK: - Session Summary

    private var sessionSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Summary")
                .font(.headline)

            SessionSummaryRow(label: "Subject", value: session.subject)
            SessionSummaryRow(label: "Duration", value: durationText)
            SessionSummaryRow(label: "Checkpoints", value: "\(session.checkpoints.count)")
            SessionSummaryRow(label: "Total Interruptions", value: "\(session.totalInterruptions)")
            if let avg = session.averageFocusRating {
                SessionSummaryRow(label: "Avg. Self-Focus", value: String(format: "%.1f/5", avg))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - No Prediction Placeholder

    private var noPredictionPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Prediction Available")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Log at least one checkpoint during a session to generate a focus prediction.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Helpers

    private var durationText: String {
        guard let min = session.actualDurationMinutes else { return "—" }
        return "\(min) min"
    }

    private var placeholderFeatures: SessionFeatures {
        SessionFeatures(
            plannedDurationMinutes: Double(session.plannedDurationMinutes),
            checkpointCount: 0,
            averageFocusRating: 3,
            totalInterruptions: 0,
            appSwitchCount: 0,
            energyLevel: session.energyLevel.featureValue,
            distractionLevelBefore: session.distractionLevelBefore.featureValue,
            averageStress: 2.5,
            averageDifficulty: 2.5,
            environmentType: session.environment.featureValue
        )
    }
}

// MARK: - Supporting Views

private struct FactorRow: View {
    let factor: ContributingFactor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(factor.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factor.label): \(factor.detail)")
    }
}

private struct SessionSummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview {
    let session = StudySession(
        subject: "Physics",
        goal: "Wave mechanics",
        plannedDurationMinutes: 60,
        environment: .library,
        energyLevel: .high,
        distractionLevelBefore: .low,
        endDate: Date(),
        checkpoints: [
            FocusCheckpoint(focusRating: 4, interruptionCount: 1, switchedAppOrTask: false, perceivedDifficulty: 3, stressLevel: 2),
            FocusCheckpoint(focusRating: 5, interruptionCount: 0, switchedAppOrTask: false, perceivedDifficulty: 4, stressLevel: 2)
        ],
        prediction: FocusPrediction(category: .deepFocus, confidence: 0.87, factorSummary: "High self-rated focus.")
    )
    PredictionResultView(session: session)
        .environmentObject(AccessibilitySettingsService.shared)
}
