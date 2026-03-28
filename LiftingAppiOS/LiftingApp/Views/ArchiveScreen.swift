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

                if !model.archiveOverview.bestEstimatedOneRepMaxByLift.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Best e1RM by Lift")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(model.archiveOverview.bestEstimatedOneRepMaxByLift) { item in
                            HStack {
                                Text(item.lift.displayName)
                                Spacer()
                                Text("\(Int(item.bestEstimatedOneRepMax)) lb")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
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
                        archiveTrendCard(title: "Weekly Volume (Tonnage)", points: model.weeklyVolumeTrend(for: run), color: .green, yAxisLabelMode: .abbreviated)
                        archiveTrendCard(title: "Fatigue Flags", points: model.fatigueTimeline(for: run), color: .orange, yAxisLabelMode: .fatigue)
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
                    .chartYScale(domain: chartDomain(for: points, mode: yAxisLabelMode))
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
                                case .abbreviated:
                                    AxisValueLabel(abbreviated(numericValue))
                                case .fatigue:
                                    AxisValueLabel(numericValue.formatted(.number.precision(.fractionLength(1))))
                                }
                            }
                        }
                    }
                    .frame(width: max(720, CGFloat(points.count) * 60), height: yAxisLabelMode == .fatigue ? 240 : 200)
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
                .chartYScale(domain: liftChartDomain(for: series))
                .chartXAxis {
                    AxisMarks(values: Array(1...12)) { value in
                        if let week = value.as(Int.self) {
                            AxisValueLabel("W\(week)")
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let numericValue = value.as(Double.self) {
                            AxisValueLabel(numericValue.formatted(.number.precision(.fractionLength(0))))
                        }
                    }
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
            switch mode {
            case .percent:
                return [-10, 0, 10]
            case .numeric:
                return [0, 1, 2]
            case .abbreviated:
                return [0, 1000, 2000]
            case .fatigue:
                return [-1, 0, 1]
            }
        }
        if minValue == maxValue {
            switch mode {
            case .percent:
                return [minValue - 5, minValue, minValue + 5]
            case .numeric:
                return [minValue - 1, minValue, minValue + 1]
            case .abbreviated:
                return [max(0, minValue * 0.8), minValue, minValue * 1.2]
            case .fatigue:
                return [minValue - 0.5, minValue, minValue + 0.5]
            }
        }
        switch mode {
        case .fatigue:
            let roundedMin = floor(minValue)
            let roundedMax = ceil(maxValue)
            if roundedMin == roundedMax {
                return [roundedMin - 0.5, roundedMin, roundedMin + 0.5]
            }
            return Array(stride(from: roundedMin, through: roundedMax, by: 1.0))
        case .numeric, .percent, .abbreviated:
            let midpoint = (minValue + maxValue) / 2
            return [minValue, midpoint, maxValue]
        }
    }

    private func chartDomain(for points: [AnalyticsPoint], mode: ArchiveTrendAxisLabelMode) -> ClosedRange<Double> {
        let values = points.compactMap(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            switch mode {
            case .percent:
                return (-10)...10
            case .fatigue:
                return (-1.5)...1.5
            case .numeric, .abbreviated:
                return 0...100
            }
        }
        let padding: Double
        switch mode {
        case .percent:
            padding = max((maxValue - minValue) * 0.15, 2)
        case .fatigue:
            padding = max((maxValue - minValue) * 0.2, 0.4)
        case .numeric, .abbreviated:
            padding = max((maxValue - minValue) * 0.15, 25)
        }
        let lower: Double
        switch mode {
        case .percent, .fatigue:
            lower = minValue - padding
        case .numeric, .abbreviated:
            lower = max(0, minValue - padding)
        }
        return lower...(maxValue + padding)
    }

    private func liftChartDomain(for series: [LiftTrendSeries]) -> ClosedRange<Double> {
        let values = series.flatMap(\.points).compactMap(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...100
        }
        let padding = max((maxValue - minValue) * 0.15, 10)
        return max(0, minValue - padding)...(maxValue + padding)
    }

    private func abbreviated(_ value: Double) -> String {
        if abs(value) >= 1000 {
            let thousands = value / 1000
            if thousands.rounded() == thousands {
                return "\(Int(thousands))k"
            }
            return String(format: "%.1fk", thousands)
        }
        return value.formatted(.number.precision(.fractionLength(0)))
    }
}

private enum ArchiveTrendAxisLabelMode {
    case numeric
    case percent
    case abbreviated
    case fatigue
}

private struct ArchiveTrendPlotPoint: Identifiable {
    let id = UUID()
    let order: Int
    let value: Double
    let segment: Int
}
