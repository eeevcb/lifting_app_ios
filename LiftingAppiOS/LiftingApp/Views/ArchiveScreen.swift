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
                        archiveTrendCard(title: "Estimated 1RM Trend", points: model.estimatedOneRepMaxTrend(for: run), color: .blue)
                        archiveTrendCard(title: "Weekly Volume", points: model.weeklyVolumeTrend(for: run), color: .green)
                        archiveTrendCard(title: "Fatigue Flags", points: model.fatigueTimeline(for: run), color: .orange)
                        archiveTrendCard(title: "Target Shifts", points: model.targetAdjustmentTimeline(for: run), color: .pink)
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

    private func archiveTrendCard(title: String, points: [AnalyticsPoint], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if points.isEmpty {
                Text("No chart data recorded for this archived run yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Week", point.order),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)

                    PointMark(
                        x: .value("Week", point.order),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                }
                .chartXAxis {
                    AxisMarks(values: points.map(\.order)) { value in
                        if let week = value.as(Int.self) {
                            AxisValueLabel("W\(week)")
                        }
                    }
                }
                .frame(height: 200)
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
}
