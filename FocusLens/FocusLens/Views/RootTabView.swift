import SwiftUI

/// Top-level tab bar navigation. Each tab is a self-contained feature area.
struct RootTabView: View {

    @StateObject private var sessionViewModel = SessionViewModel()
    @State private var showSessionSetup = false
    @State private var showActiveSession = false
    @EnvironmentObject private var accessibility: AccessibilitySettingsService

    var body: some View {
        TabView {
            homeTab
                .tabItem {
                    Label("Study", systemImage: "book.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .sheet(isPresented: $showSessionSetup, onDismiss: handleSetupDismiss) {
            SessionSetupView(viewModel: sessionViewModel)
        }
        .fullScreenCover(isPresented: $showActiveSession) {
            ActiveSessionView(viewModel: sessionViewModel)
                .environmentObject(accessibility)
        }
        .sheet(isPresented: $sessionViewModel.showPredictionResult) {
            if let session = sessionViewModel.activeSession {
                PredictionResultView(session: session)
                    .environmentObject(accessibility)
            }
        }
    }

    // MARK: - Home Tab

    private var homeTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    welcomeHeader
                    startSessionCard
                    quickStatsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("FocusLens")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ready to focus?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start a session and FocusLens will generate an on-device focus prediction when you finish.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Start Session Card

    private var startSessionCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("On-Device ML")
                    .font(.headline)
                Text("Your focus prediction runs entirely on this device — private, fast, and offline-capable.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showSessionSetup = true }) {
                Text("Start Study Session")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Start a new study session")
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        let sessions = LocalStorageService.shared.loadSessions().filter { $0.isComplete }
        let count = sessions.count
        let lastSession = sessions.sorted { $0.startDate > $1.startDate }.first

        return VStack(alignment: .leading, spacing: 14) {
            Text("Quick Stats")
                .font(.headline)

            HStack(spacing: 14) {
                QuickStatPill(label: "Sessions", value: "\(count)", systemImage: "number")

                if let last = lastSession, let pred = last.prediction {
                    QuickStatPill(
                        label: "Last Result",
                        value: pred.category.rawValue,
                        systemImage: pred.category.systemImageName
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Handlers

    private func handleSetupDismiss() {
        if sessionViewModel.isSessionActive {
            showActiveSession = true
        }
    }
}

// MARK: - QuickStatPill

private struct QuickStatPill: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Settings View

struct SettingsView: View {

    @EnvironmentObject private var accessibility: AccessibilitySettingsService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showDeleteAllAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Reduce Motion", isOn: $accessibility.reducedMotion)
                        .accessibilityLabel("Reduce motion animations")

                    Toggle("Low Visual Clutter", isOn: $accessibility.lowVisualClutter)
                        .accessibilityLabel("Reduce visual complexity in the interface")

                    Toggle("High Contrast", isOn: $accessibility.highContrast)
                        .accessibilityLabel("Increase text and element contrast")
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("These supplement — and do not override — iOS system accessibility settings.")
                }

                Section {
                    Button("View Privacy Information") {
                        hasCompletedOnboarding = false
                    }
                    .accessibilityLabel("View the FocusLens privacy and onboarding information")

                    Button(role: .destructive) {
                        showDeleteAllAlert = true
                    } label: {
                        Label("Delete All Session Data", systemImage: "trash")
                    }
                    .accessibilityLabel("Permanently delete all local study session data")
                } header: {
                    Text("Privacy & Data")
                } footer: {
                    Text("All data is stored locally. Deletion is permanent and cannot be undone.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Portfolio)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("ML Model")
                        Spacer()
                        Text("On-Device / Heuristic Fallback")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    HStack {
                        Text("Data Storage")
                        Spacer()
                        Text("Local JSON")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data?", isPresented: $showDeleteAllAlert) {
                Button("Delete", role: .destructive) {
                    LocalStorageService.shared.deleteAllSessions()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All session history will be permanently removed from this device.")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootTabView()
        .environmentObject(AccessibilitySettingsService.shared)
}
