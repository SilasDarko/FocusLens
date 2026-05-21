import SwiftUI
import Charts

/// Displays aggregate insights calculated locally from past session data.
/// Uses deterministic arithmetic — no additional ML model is needed here.
struct InsightsView: View {

    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.hasEnoughData {
                    insightsContent
                } else {
                    insufficientDataView
                }
            }
            .navigationTitle("Insights")
            .onAppear { viewModel.computeInsights() }
        }
    }

    // MARK: - Main Content

    private var insightsContent: some View {
        VStack(spacing: 20) {
            statsGrid
            if !viewModel.recentTrend.isEmpty {
                trendChart
            }
            bestEnvironmentCard
            dataSourceNote
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 14
        ) {
            if let category = viewModel.mostCommonCategory {
                StatCard(
                    title: "Most Common",
                    value: category.rawValue,
                    systemImage: category.systemImageName,
                    tint: .accentColor
                )
            }

            StatCard(
                title: "Avg. Interruptions",
                value: String(format: "%.1f / session", viewModel.averageInterruptionsPerSession),
                systemImage: "bell.badge",
                tint: .orange
            )

            StatCard(
                title: "Sessions Analyzed",
                value: "\(viewModel.totalSessionCount)",
                systemImage: "calendar",
                tint: .blue
            )

            if let env = viewModel.bestEnvironment {
                StatCard(
                    title: "Best Environment",
                    value: env.rawValue,
                    systemImage: "location.fill",
                    tint: .green
                )
            }
        }
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Trend (Recent Sessions)")
                .font(.headline)

            Chart(viewModel.recentTrend) { point in
                LineMark(
                    x: .value("Session", point.dateLabel),
                    y: .value("Focus", point.focusScore)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Session", point.dateLabel),
                    y: .value("Focus", point.focusScore)
                )
                .foregroundStyle(Color.accentColor)
                .symbolSize(60)
            }
            .chartYScale(domain: 1...5)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)").font(.caption)
                        }
                    }
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Line chart showing self-rated focus scores across recent sessions")
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Best Environment Card

    @ViewBuilder
    private var bestEnvironmentCard: some View {
        if let env = viewModel.bestEnvironment {
            VStack(alignment: .leading, spacing: 10) {
                Label("Strongest Environment", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Your sessions in **\(env.rawValue)** environments have historically shown the best predicted focus outcomes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Best environment for focus: \(env.rawValue)")
        }
    }

    // MARK: - Insufficient Data

    private var insufficientDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Not Enough Data Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Complete at least 2 study sessions to start seeing insights.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("\(viewModel.totalSessionCount) of 2 sessions needed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Data Source Note

    private var dataSourceNote: some View {
        Text("Insights are calculated locally from your on-device session history. No data leaves your device.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Preview

#Preview {
    InsightsView()
}
