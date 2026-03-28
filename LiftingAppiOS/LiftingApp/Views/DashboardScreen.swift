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
                    trendCard(title: "Target Shifts", points: model.targetAdjustmentTimeline, color: .pink, yAxisLabelMode: .percent)
                    recommendationCard
                    liftSummaryCard
                    recentCallsCard
                    variationCard
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    private func trendCard(title: String, points: [AnalyticsPoint], color: Color, yAxisLabelMode: TrendAxisLabelMode = .numeric) -> some View {
        let plottedPoints = segmentedPoints(from: points)

        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(plottedPoints) { point in
                        LineMark(
                            x: .value("Week", point.order),
                            y: .value("Value", point.value),
                            series: .value("Segment", point.segment)
                        )
                        .foregroundStyle(color)

                        PointMark(
                            x: .value("Week", point.order),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                    }
                }
                .chartXScale(domain: 1...12)
                .chartXAxis {
                    AxisMarks(values: points.map(\.order)) { value in
                        if let week = value.as(Int.self) {
                            AxisValueLabel("W\(week)")
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        if let numericValue = value.as(Double.self) {
                            switch yAxisLabelMode {
                            case .numeric:
                                AxisValueLabel(numericValue.formatted(.number.precision(.fractionLength(0))))
                            case .percent:
                                AxisValueLabel("\(Int(numericValue))%")
                            }
                        }
                    }
                }
                .frame(width: max(720, CGFloat(points.count) * 60), height: 220)
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progression Mix")
                .font(.headline)

            ForEach(model.recommendationCounts) { item in
                HStack {
                    Text(item.recommendation.displayName)
                    Spacer()
                    Text("\(item.count)")
                        .foregroundStyle(color(for: item.recommendation))
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))
            }
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
                        Text("Avg fatigue \(signedDelta(snapshot.averageFatigueDelta))")
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
                        Text(snapshot.latestRecommendation.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: snapshot.latestRecommendation))
                    }
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var recentCallsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Engine Calls")
                .font(.headline)

            ForEach(model.recentFatigueSummaries) { session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(session.programEntry.primaryLift.displayName) - W\(session.programEntry.week)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(session.fatigue.recommendation.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: session.fatigue.recommendation))
                    }

                    HStack {
                        Text("Delta \(signedDelta(session.fatigue.effortDelta))")
                        Spacer()
                        Text("Target \(signedPercent(session.fatigue.targetAdjustmentPercent))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(session.fatigue.backoffDecisionReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    Text("\(Int(point.value ?? 0))")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func color(for recommendation: EngineRecommendation) -> Color {
        switch recommendation {
        case .hold:
            .green
        case .reduce:
            .orange
        case .deload:
            .red
        }
    }

    private func signedDelta(_ value: Double) -> String {
        if value > 0 {
            return String(format: "+%.2f", value)
        }
        return String(format: "%.2f", value)
    }

    private func signedPercent(_ value: Double) -> String {
        let percent = value * 100
        if percent > 0 {
            return String(format: "+%.0f%%", percent)
        }
        return String(format: "%.0f%%", percent)
    }

    private func segmentedPoints(from points: [AnalyticsPoint]) -> [TrendPlotPoint] {
        var segment = 0
        var plotted: [TrendPlotPoint] = []

        for point in points {
            guard let value = point.value else {
                segment += 1
                continue
            }

            plotted.append(TrendPlotPoint(order: point.order, value: value, segment: segment))
        }

        return plotted
    }
}

private enum TrendAxisLabelMode {
    case numeric
    case percent
}

private struct TrendPlotPoint: Identifiable {
    let id = UUID()
    let order: Int
    let value: Double
    let segment: Int
}
