import SwiftUI

/// Collects session metadata before a study session begins.
struct SessionSetupView: View {

    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                sessionDetailsSection
                environmentSection
                wellbeingSection
                accessibilitySection
                startSection
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel new session")
                }
            }
        }
    }

    // MARK: - Form Sections

    private var sessionDetailsSection: some View {
        Section {
            LabeledFormField(label: "Subject / Course") {
                TextField("e.g. Organic Chemistry", text: $viewModel.subject)
                    .textInputAutocapitalization(.words)
            }

            LabeledFormField(label: "Session Goal") {
                TextField("e.g. Finish Chapter 7 problems", text: $viewModel.goal)
                    .textInputAutocapitalization(.sentences)
            }

            Stepper(
                value: $viewModel.plannedDurationMinutes,
                in: 5...240,
                step: 5
            ) {
                HStack {
                    Text("Planned Duration")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(viewModel.plannedDurationFormatted)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityLabel("Planned duration: \(viewModel.plannedDurationFormatted)")
        } header: {
            Text("Session Details")
        }
    }

    private var environmentSection: some View {
        Section {
            Picker("Environment", selection: $viewModel.environment) {
                ForEach(EnvironmentType.allCases) { env in
                    Text(env.rawValue).tag(env)
                }
            }
            .accessibilityLabel("Study environment: \(viewModel.environment.rawValue)")
        } header: {
            Text("Environment")
        } footer: {
            Text("Where will you be studying?")
        }
    }

    private var wellbeingSection: some View {
        Section {
            Picker("Energy Level", selection: $viewModel.energyLevel) {
                ForEach(EnergyLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .accessibilityLabel("Current energy level: \(viewModel.energyLevel.rawValue)")

            Picker("Distraction Level (pre-session)", selection: $viewModel.distractionLevelBefore) {
                ForEach(DistractionLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .accessibilityLabel("Distraction level before session: \(viewModel.distractionLevelBefore.rawValue)")
        } header: {
            Text("Current State")
        } footer: {
            Text("Honest ratings help produce more accurate focus predictions.")
        }
    }

    private var accessibilitySection: some View {
        Section {
            TextField(
                "e.g. Large text, reduced motion, low clutter",
                text: $viewModel.accessibilityNotes,
                axis: .vertical
            )
            .lineLimit(3, reservesSpace: true)
            .textInputAutocapitalization(.sentences)
        } header: {
            Text("Accessibility Notes (Optional)")
        } footer: {
            Text("Note any preferences so you can track whether they affect your focus outcomes.")
        }
    }

    private var startSection: some View {
        Section {
            Button(action: startSession) {
                HStack {
                    Spacer()
                    Text("Start Session")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(!viewModel.canStartSession)
            .foregroundStyle(viewModel.canStartSession ? Color.accentColor : .secondary)
            .accessibilityLabel("Start study session")
            .accessibilityHint(viewModel.canStartSession ? "" : "Add a subject and goal to continue")
        }
    }

    private func startSession() {
        viewModel.startSession()
        dismiss()
    }
}

// MARK: - LabeledFormField

/// A simple container that ensures consistent label styling in forms.
private struct LabeledFormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - Preview

#Preview {
    SessionSetupView(viewModel: SessionViewModel())
}
