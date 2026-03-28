import Charts
import SwiftUI

struct DashboardScreen: View {
    @Environment(AppModel.self) private var model

    private let cardBackground = Color(uiColor: .secondarySystemBackground)
    private let insetBackground = Color(uiColor: .systemBackground)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.completedSessions.isEmpty {
                    ContentUnavailableView("No Analytics Yet", systemImage: "chart.bar.xaxis", description: Text("Finish a workout to start generating real analytics."))
                } else {
                    trendCard(title: "Estimated 1RM Trend", points: model.estimatedOneRepMaxTrend, color: .blue)
                    trendCard(title: "Weekly Volume", points: model.weeklyVolumeTrend, color: .green)
                    trendCard(title: "Fatigue Flags", points: model.fatigueTimeline, color: .orange)
                    liftSummaryCard
                    variationCard
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    private func trendCard(title: String, points: [AnalyticsPoint], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Chart(points) { point in
                LineMark(
                    x: .value("Label", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)

                PointMark(
                    x: .value("Label", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
            }
            .frame(height: 220)
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var liftSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Lift")
                .font(.headline)

            ForEach(model.liftSnapshots) { snapshot in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.lift.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("Best e1RM \(Int(snapshot.bestEstimatedOneRepMax)) lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(snapshot.tonnage)) lb")
                            .font(.subheadline.weight(.semibold))
                        Text("\(snapshot.variationCount) variation sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var variationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Variation Usage")
                .font(.headline)

            ForEach(model.variationUsage.prefix(5)) { point in
                HStack {
                    Text(point.label)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(point.value))")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }
}
