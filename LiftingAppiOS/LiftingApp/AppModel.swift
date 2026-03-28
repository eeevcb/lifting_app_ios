import Foundation
import Observation

@Observable
final class AppModel {
    var selectedTab: AppTab = .workout
    var programStartDate: Date
    var selectedWeek: Int
    var selectedDay: TrainingDay
    var drafts: [String: SessionDraft]
    var completedSessions: [CompletedSession]
    var liftStates: [LiftType: LiftState]

    private let persistence = PersistenceController()

    init() {
        if let snapshot = persistence.load() {
            programStartDate = snapshot.programStartDate
            selectedWeek = snapshot.selectedWeek
            selectedDay = snapshot.selectedDay
            drafts = snapshot.drafts
            completedSessions = snapshot.completedSessions
            liftStates = snapshot.liftStates
        } else {
            programStartDate = ProgramDefinition.defaultStartDate
            selectedWeek = ProgramDefinition.weeks().first ?? 1
            selectedDay = .friday
            drafts = [:]
            completedSessions = []
            liftStates = LiftState.defaults
        }

        ensureDraftForSelection()
    }

    var weeks: [Int] {
        ProgramDefinition.weeks()
    }

    var currentEntry: ProgramEntry? {
        ProgramDefinition.entry(week: selectedWeek, day: selectedDay)
    }

    var currentLiftState: LiftState? {
        guard let currentEntry else { return nil }
        return liftStates[currentEntry.primaryLift]
    }

    var currentDraft: SessionDraft? {
        guard let currentEntry else { return nil }
        return drafts[currentEntry.key]
    }

    var currentSummary: SessionSummary? {
        guard let draft = currentDraft else { return nil }
        return SessionSummary(
            totalVolume: draft.sets.reduce(0) { $0 + $1.volumeContribution },
            bestEstimatedOneRepMax: draft.sets.compactMap { WorkoutEngine.estimateOneRepMax(weight: $0.weight, reps: $0.reps) }.max(),
            completedSetCount: draft.sets.filter { $0.completed && !$0.skipped }.count,
            variationUsed: draft.selectedVariation.isEmpty ? nil : draft.selectedVariation
        )
    }

    var currentTargetWeight: Double? {
        guard let entry = currentEntry, let liftState = currentLiftState else { return nil }
        let target = WorkoutEngine.targetWeight(for: entry, liftState: liftState)
        return target == 0 ? nil : target
    }

    var estimatedOneRepMaxTrend: [AnalyticsPoint] {
        completedSessions
            .sorted { $0.performedOn < $1.performedOn }
            .compactMap { session in
                guard let value = session.summary.bestEstimatedOneRepMax else { return nil }
                return AnalyticsPoint(label: "W\(session.programEntry.week)", value: value)
            }
    }

    var weeklyVolumeTrend: [AnalyticsPoint] {
        let grouped = Dictionary(grouping: completedSessions, by: { $0.programEntry.week })
        return grouped.keys.sorted().map { week in
            let volume = grouped[week]?.reduce(0) { $0 + $1.summary.totalVolume } ?? 0
            return AnalyticsPoint(label: "W\(week)", value: volume)
        }
    }

    var fatigueTimeline: [AnalyticsPoint] {
        completedSessions
            .sorted { $0.performedOn < $1.performedOn }
            .map { session in
                AnalyticsPoint(label: "W\(session.programEntry.week)", value: session.fatigue.actualEffort - session.fatigue.expectedEffort)
            }
    }

    var liftSnapshots: [LiftAnalyticsSnapshot] {
        LiftType.allCases.map { lift in
            let sessions = completedSessions.filter { $0.programEntry.primaryLift == lift }
            let tonnage = sessions.reduce(0) { $0 + $1.summary.totalVolume }
            let bestEstimatedOneRepMax = sessions.compactMap(\.summary.bestEstimatedOneRepMax).max() ?? liftStates[lift]?.estimatedOneRepMax ?? 0
            let variationCount = sessions.filter { !($0.summary.variationUsed ?? "").isEmpty }.count
            return LiftAnalyticsSnapshot(lift: lift, tonnage: tonnage, bestEstimatedOneRepMax: bestEstimatedOneRepMax, variationCount: variationCount)
        }
    }

    var variationUsage: [AnalyticsPoint] {
        let grouped = Dictionary(grouping: completedSessions.filter { !$0.variation.isEmpty }, by: \.variation)
        return grouped
            .map { AnalyticsPoint(label: $0.key, value: Double($0.value.count)) }
            .sorted { $0.value > $1.value }
    }

    var groupedProgram: [(week: Int, entries: [ProgramEntry])] {
        Dictionary(grouping: ProgramDefinition.programDays, by: \.week)
            .keys
            .sorted()
            .map { week in
                let entries = ProgramDefinition.programDays
                    .filter { $0.week == week }
                    .sorted { $0.day.weekdayIndex < $1.day.weekdayIndex }
                return (week, entries)
            }
    }

    func select(week: Int, day: TrainingDay) {
        selectedWeek = week
        selectedDay = day
        ensureDraftForSelection()
        persist()
    }

    func updateProgramStartDate(_ date: Date) {
        programStartDate = date
        persist()
    }

    func updateEstimatedOneRepMax(for lift: LiftType, to value: Double) {
        guard value > 0 else { return }
        var state = liftStates[lift] ?? LiftState.defaults[lift]!
        state.estimatedOneRepMax = value
        if state.trainingMax == 0 {
            state.trainingMax = value * 0.95
        }
        liftStates[lift] = state
        regenerateCurrentDraft()
        persist()
    }

    func updateVariation(_ value: String) {
        guard var draft = currentDraft, let currentEntry else { return }
        draft.selectedVariation = value
        draft.sets = draft.sets.map { set in
            var updated = set
            if updated.setType == .variation {
                updated.exerciseName = value
            }
            return updated
        }
        drafts[currentEntry.key] = draft
        persist()
    }

    func updateSet(_ setID: UUID, mutate: (inout WorkoutSet) -> Void) {
        guard let currentEntry, var draft = drafts[currentEntry.key] else { return }
        guard let index = draft.sets.firstIndex(where: { $0.id == setID }) else { return }
        mutate(&draft.sets[index])
        drafts[currentEntry.key] = draft
        persist()
    }

    func addSet(_ type: WorkoutSetType) {
        guard let currentEntry, let liftState = currentLiftState, let draft = drafts[currentEntry.key] else { return }
        drafts[currentEntry.key] = WorkoutEngine.addSet(to: draft, setType: type, liftState: liftState)
        persist()
    }

    func removeSet(_ setID: UUID) {
        guard let currentEntry, var draft = drafts[currentEntry.key] else { return }
        draft.sets.removeAll { $0.id == setID }
        draft.sets = draft.sets.sortedForDisplay().enumerated().map { index, set in
            var updated = set
            updated.setOrder = index + 1
            return updated
        }
        drafts[currentEntry.key] = draft
        persist()
    }

    func finishWorkout() {
        guard let entry = currentEntry, let draft = drafts[entry.key], let liftState = currentLiftState else { return }
        let result = WorkoutEngine.completeSession(draft, liftState: liftState)
        liftStates[entry.primaryLift] = result.updatedLiftState
        completedSessions.append(result.completedSession)
        drafts[entry.key] = WorkoutEngine.makeDraft(for: entry, liftState: result.updatedLiftState, variation: draft.selectedVariation)
        refreshFutureDrafts(for: entry.primaryLift, after: entry, using: result.updatedLiftState)
        persist()
    }

    func sessionDate(for entry: ProgramEntry) -> Date {
        let calendar = Calendar.current
        let startWeekday = calendar.component(.weekday, from: programStartDate)
        let offsetToTarget = (entry.day.weekdayIndex - startWeekday + 7) % 7
        let dayOffset = (entry.week - 1) * 7 + offsetToTarget
        return calendar.date(byAdding: .day, value: dayOffset, to: programStartDate) ?? programStartDate
    }

    func completedSession(for entry: ProgramEntry) -> CompletedSession? {
        completedSessions.last { $0.programEntry.key == entry.key }
    }

    private func ensureDraftForSelection() {
        guard let entry = currentEntry else { return }
        if drafts[entry.key] == nil {
            let liftState = liftStates[entry.primaryLift] ?? LiftState.defaults[entry.primaryLift]!
            drafts[entry.key] = WorkoutEngine.makeDraft(for: entry, liftState: liftState, variation: nil)
        }
        persist()
    }

    private func regenerateCurrentDraft() {
        guard let entry = currentEntry else { return }
        let variation = drafts[entry.key]?.selectedVariation
        let liftState = liftStates[entry.primaryLift] ?? LiftState.defaults[entry.primaryLift]!
        drafts[entry.key] = WorkoutEngine.makeDraft(for: entry, liftState: liftState, variation: variation)
    }

    private func persist() {
        let snapshot = AppSnapshot(
            programStartDate: programStartDate,
            selectedWeek: selectedWeek,
            selectedDay: selectedDay,
            drafts: drafts,
            completedSessions: completedSessions,
            liftStates: liftStates
        )
        persistence.save(snapshot: snapshot)
    }

    private func refreshFutureDrafts(for lift: LiftType, after completedEntry: ProgramEntry, using liftState: LiftState) {
        for (key, draft) in drafts {
            guard draft.programEntry.primaryLift == lift else { continue }
            guard draft.programEntry.key != completedEntry.key else { continue }
            guard isAfter(draft.programEntry, completedEntry) else { continue }
            guard completedSession(for: draft.programEntry) == nil else { continue }

            drafts[key] = WorkoutEngine.makeDraft(
                for: draft.programEntry,
                liftState: liftState,
                variation: draft.selectedVariation
            )
        }
    }

    private func isAfter(_ lhs: ProgramEntry, _ rhs: ProgramEntry) -> Bool {
        if lhs.week != rhs.week {
            return lhs.week > rhs.week
        }
        return lhs.day.weekdayIndex > rhs.day.weekdayIndex
    }
}
