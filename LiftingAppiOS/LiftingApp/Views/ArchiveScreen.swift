import Charts
import SwiftUI

struct ArchiveScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            if model.archivedRuns.isEmpty {
                ContentUnavailableView(
                    "No Archived Programs",
                    systemImage: "archivebox",
                    description: Text("Finish and archive a run from the Program tab to keep its history here.")
                )
            } else {
                overviewSection
                archivedProgramsSection
            }
        }
        .navigationTitle("Archive")
    }

    private var overviewSection: some View {
        Section("Overview") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    overviewMetric(title: "Programs", value: "\(model.archiveOverview.archivedProgramCount)")
                    overviewMetric(title: "Workouts", value: "\(model.archiveOverview.totalArchivedWorkouts)")
                }

                HStack {
                    overviewMetric(title: "Tonnage", value: "\(Int(model.archiveOverview.totalArchivedTonnage)) lb")
                    overviewMetric(title: "Best e1RM", value: model.archiveOverview.bestArchivedEstimatedOneRepMax > 0 ? "\(Int(model.archiveOverview.bestArchivedEstimatedOneRepMax)) lb" : "--")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var archivedProgramsSection: some View {
        Section("Finished Programs") {
            ForEach(model.archivedRunSummaries) { summary in
                NavigationLink {
                    ArchiveRunDetailScreen(runID: summary.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Started \(summary.startedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(summary.completedWorkoutCount) workouts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Adherence \(percentString(summary.adherenceRate))")
                            Spacer()
                            Text("Tonnage \(Int(summary.totalTonnage)) lb")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        model.deleteArchivedRun(summary.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func overviewMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

private struct ArchiveRunDetailScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let runID: UUID

    var body: some View {
        Group {
            if let run = model.archivedRun(with: runID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ProgramSummaryCard(summary: model.summary(for: run), isArchived: true)
                        archiveLiftTrendCard(title: "Estimated 1RM Trend", series: model.estimatedOneRepMaxTrendByLift(for: run))
                        archiveTrendCard(title: "Weekly Volume (Tonnage)", points: model.weeklyVolumeTrend(for: run), color: .green)
                        archiveTrendCard(title: "Fatigue Flags", points: model.fatigueTimeline(for: run), color: .orange)
                        archiveTrendCard(title: "Target Shifts", points: model.targetAdjustmentTimeline(for: run), color: .pink, yAxisLabelMode: .percent)
                        liftCalloutsCard(summary: model.summary(for: run))
                        historyCard(run: run)
                    }
                    .padding()
                }
                .navigationTitle("Archived Program")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            model.deleteArchivedRun(runID)
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Archived Program Removed", systemImage: "trash", description: Text("This archived run is no longer available."))
            }
        }
    }

    private func archiveTrendCard(title: String, points: [AnalyticsPoint], color: Color, yAxisLabelMode: ArchiveTrendAxisLabelMode = .numeric) -> some View {
        let plottedPoints = segmentedPoints(from: points)

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if points.allSatisfy({ $0.value == nil }) {
                Text("No chart data recorded for this archived run yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
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
                        AxisMarks(values: Array(1...12)) { value in
                            if let week = value.as(Int.self) {
                                AxisValueLabel("W\(week)")
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: axisValues(for: points, mode: yAxisLabelMode)) { value in
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
                    .frame(width: max(720, CGFloat(points.count) * 60), height: 200)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func archiveLiftTrendCard(title: String, series: [LiftTrendSeries]) -> some View {
        let plottedSeries = series.map { (series: $0, points: segmentedPoints(from: $0.points)) }

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(series) { item in
                    Label(item.lift.displayName, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(color(for: item.lift))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(Array(plottedSeries.enumerated()), id: \.offset) { _, item in
                        ForEach(item.points) { point in
                            LineMark(
                                x: .value("Week", point.order),
                                y: .value("Value", point.value),
                                series: .value("Series", "\(item.series.lift.rawValue)-\(point.segment)")
                            )
                            .foregroundStyle(color(for: item.series.lift))

                            PointMark(
                                x: .value("Week", point.order),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(color(for: item.series.lift))
                        }
                    }
                }
                .chartXScale(domain: 1...12)
                .chartXAxis {
                    AxisMarks(values: Array(1...12)) { value in
                        if let week = value.as(Int.self) {
                            AxisValueLabel("W\(week)")
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
                }
                .frame(width: max(720, CGFloat(12) * 60), height: 240)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func liftCalloutsCard(summary: ProgramRunSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lift Highlights")
                .font(.headline)

            ForEach(summary.liftCallouts) { callout in
                VStack(alignment: .leading, spacing: 6) {
                    Text(callout.lift.displayName)
                        .font(.subheadline.weight(.semibold))
                    HStack {
                        Text("Best e1RM \(Int(callout.bestEstimatedOneRepMax)) lb")
                        Spacer()
                        Text("Best working set \(Int(callout.bestWorkingWeight)) lb")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func historyCard(run: ProgramRun) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session History")
                .font(.headline)

            ForEach(model.sessions(for: run)) { session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("W\(session.programEntry.week) \(session.programEntry.day.rawValue) - \(session.programEntry.primaryLift.displayName)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(session.fatigue.recommendation.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color(for: session.fatigue.recommendation))
                    }

                    HStack {
                        Text("Volume \(Int(session.summary.totalVolume)) lb")
                        Spacer()
                        Text("Best e1RM \(session.summary.bestEstimatedOneRepMax.map { String(Int($0)) } ?? "--") lb")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
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

    private func color(for lift: LiftType) -> Color {
        switch lift {
        case .squat:
            return .blue
        case .bench:
            return .green
        case .deadlift:
            return .purple
        case .shoulderPress:
            return .orange
        case .barbellRow:
            return .brown
        }
    }

    private func segmentedPoints(from points: [AnalyticsPoint]) -> [ArchiveTrendPlotPoint] {
        var segment = 0
        var plotted: [ArchiveTrendPlotPoint] = []

        for point in points {
            guard let value = point.value else {
                segment += 1
                continue
            }

            plotted.append(ArchiveTrendPlotPoint(order: point.order, value: value, segment: segment))
        }

        return plotted
    }

    private func axisValues(for points: [AnalyticsPoint], mode: ArchiveTrendAxisLabelMode) -> [Double] {
        let values = points.compactMap(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return mode == .percent ? [-10, 0, 10] : [0, 1, 2]
        }
        if minValue == maxValue {
            return mode == .percent
                ? [minValue - 5, minValue, minValue + 5]
                : [minValue - 1, minValue, minValue + 1]
        }
        let midpoint = (minValue + maxValue) / 2
        return [minValue, midpoint, maxValue]
    }
}

private enum ArchiveTrendAxisLabelMode {
    case numeric
    case percent
}

private struct ArchiveTrendPlotPoint: Identifiable {
    let id = UUID()
    let order: Int
    let value: Double
    let segment: Int
}
