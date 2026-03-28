import SwiftUI

struct ProgramScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                DatePicker("Program Start", selection: Binding(
                    get: { model.programStartDate },
                    set: { model.updateProgramStartDate($0) }
                ), displayedComponents: .date)
            }

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
                        Text(completedSession.fatigue.recommendation.rawValue.capitalized)
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
