import SwiftUI

struct ProgramScreen: View {
    @Environment(AppModel.self) private var model
    @State private var showingNewProgramDialog = false

    var body: some View {
        List {
            setupSection
            activeRunSection

            ForEach(model.groupedProgram, id: \.week) { group in
                Section("Week \(group.week)") {
                    ForEach(group.entries) { entry in
                        ProgramRow(
                            entry: entry,
                            sessionDate: model.sessionDate(for: entry),
                            isSelected: model.selectedWeek == entry.week && model.selectedDay == entry.day,
                            completedSession: model.completedSession(for: entry),
                            onSelect: {
                                model.select(week: entry.week, day: entry.day)
                                model.selectedTab = .workout
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Program")
        .confirmationDialog("Start a New Program?", isPresented: $showingNewProgramDialog, titleVisibility: .visible) {
            Button("Archive Current Program and Restart") {
                model.startNewProgram(archiveCurrent: true, startDate: model.programStartDate)
            }
            Button("Continue Current Program", role: .cancel) {}
        } message: {
            Text("This will move the current run into Archive and start a fresh Week 1 cycle using your current lift state.")
        }
    }

    private var setupSection: some View {
        Section("Setup") {
            DatePicker("Program Start", selection: Binding(
                get: { model.programStartDate },
                set: { model.updateProgramStartDate($0) }
            ), displayedComponents: .date)
        }
    }

    private var activeRunSection: some View {
        Section("Current Run") {
            ProgramSummaryCard(summary: model.activeRunSummary, isArchived: false)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)

            Button(model.activeRunHasActivity ? "Start New Program" : "Start Fresh Program") {
                if model.activeRunHasActivity {
                    showingNewProgramDialog = true
                } else {
                    model.startNewProgram(archiveCurrent: false, startDate: model.programStartDate)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

private struct ProgramRow: View {
    let entry: ProgramEntry
    let sessionDate: Date
    let isSelected: Bool
    let completedSession: CompletedSession?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.day.rawValue) - \(entry.primaryLift.displayName)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(sessionDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let completedSession {
                        Text(completedSession.fatigue.recommendation.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }

                Text("Plan: \(entry.planLabel)")
                    .foregroundStyle(.secondary)

                Text(entry.phase.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSelected ? .blue.opacity(0.18) : .gray.opacity(0.12), in: Capsule())
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

struct ProgramSummaryCard: View {
    let summary: ProgramRunSummary
    let isArchived: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isArchived ? "Archived Program" : "Active Program")
                        .font(.headline)
                    Text(dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(summary.completedWorkoutCount) workouts")
                    .font(.subheadline.weight(.semibold))
            }

            HStack {
                summaryMetric(title: "Adherence", value: percentString(summary.adherenceRate))
                summaryMetric(title: "Tonnage", value: "\(Int(summary.totalTonnage)) lb")
            }

            HStack {
                summaryMetric(title: "Avg Fatigue", value: signedDelta(summary.averageFatigueDelta))
                summaryMetric(title: "Deloads", value: "\(count(for: .deload))")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var dateRange: String {
        let start = summary.startedAt.formatted(date: .abbreviated, time: .omitted)
        let end = (summary.endedAt ?? .now).formatted(date: .abbreviated, time: .omitted)
        return "\(start) - \(end)"
    }

    private func count(for recommendation: EngineRecommendation) -> Int {
        summary.recommendationCounts.first(where: { $0.recommendation == recommendation })?.count ?? 0
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private func signedDelta(_ value: Double) -> String {
        if value > 0 {
            return String(format: "+%.2f", value)
        }
        return String(format: "%.2f", value)
    }
}
