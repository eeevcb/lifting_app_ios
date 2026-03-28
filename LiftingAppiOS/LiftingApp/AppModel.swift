import Foundation
import Observation

@Observable
final class AppModel {
    var selectedTab: AppTab = .workout
    var programStartDate: Date
    var selectedWeek: Int
    var selectedDay: TrainingDay
    var lastAutoSelectedDate: Date?
    var lastUsedRestDurationSeconds: Int
    var drafts: [String: SessionDraft]
    var activeRun: ProgramRun
    var archivedRuns: [ProgramRun]
    var liftStates: [LiftType: LiftState]
    var lastCompletionSummary: CompletedSession?

    private let persistence = PersistenceController()

    init() {
        if let snapshot = persistence.load() {
            programStartDate = snapshot.programStartDate
            selectedWeek = snapshot.selectedWeek
            selectedDay = snapshot.selectedDay
            lastAutoSelectedDate = snapshot.lastAutoSelectedDate
            lastUsedRestDurationSeconds = snapshot.lastUsedRestDurationSeconds
            drafts = snapshot.drafts
            activeRun = snapshot.activeRun
            archivedRuns = snapshot.archivedRuns
            liftStates = snapshot.liftStates
        } else {
            let defaultStartDate = ProgramDefinition.defaultStartDate
            programStartDate = defaultStartDate
            selectedWeek = ProgramDefinition.weeks().first ?? 1
            selectedDay = .friday
            lastAutoSelectedDate = nil
            lastUsedRestDurationSeconds = 180
            drafts = [:]
            activeRun = ProgramRun(startedAt: defaultStartDate, programStartDate: defaultStartDate)
            archivedRuns = []
            liftStates = LiftState.defaults
        }

        lastCompletionSummary = nil
        activeRun.programStartDate = programStartDate
        autoSelectTodayIfNeeded()
        ensureDraftForSelection()
    }

    var weeks: [Int] {
        ProgramDefinition.weeks()
    }

    var completedSessions: [CompletedSession] {
        activeRun.completedSessions
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

    var currentCompletedSession: CompletedSession? {
        guard let currentEntry else { return nil }
        return completedSession(for: currentEntry)
    }

    var latestCompletedSessionForCurrentLift: CompletedSession? {
        guard let currentEntry else { return nil }
        return completedSessions
            .filter { $0.programEntry.primaryLift == currentEntry.primaryLift }
            .sorted { $0.performedOn > $1.performedOn }
            .first
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
        weekOrderedPoints(from: completedSessions) { _, sessions in
            sessions.compactMap(\.summary.bestEstimatedOneRepMax).max()
        }
    }

    var weeklyVolumeTrend: [AnalyticsPoint] {
        weekOrderedPoints(from: completedSessions) { _, sessions in
            sessions.reduce(0) { $0 + $1.summary.totalVolume }
        }
    }

    var fatigueTimeline: [AnalyticsPoint] {
        weekOrderedPoints(from: completedSessions) { _, sessions in
            let deltas = sessions.map(\.fatigue.effortDelta)
            guard !deltas.isEmpty else { return nil }
            return deltas.reduce(0, +) / Double(deltas.count)
        }
    }

    var targetAdjustmentTimeline: [AnalyticsPoint] {
        weekOrderedPoints(from: completedSessions) { _, sessions in
            let shifts = sessions.map { $0.fatigue.targetAdjustmentPercent * 100 }
            guard !shifts.isEmpty else { return nil }
            return shifts.reduce(0, +) / Double(shifts.count)
        }
    }

    var recommendationCounts: [RecommendationCount] {
        recommendationCounts(for: completedSessions)
    }

    var liftSnapshots: [LiftAnalyticsSnapshot] {
        liftSnapshots(for: completedSessions)
    }

    var variationUsage: [AnalyticsPoint] {
        let grouped = Dictionary(grouping: completedSessions.filter { !$0.variation.isEmpty }, by: \.variation)
        return grouped
            .map { AnalyticsPoint(order: $0.value.count, label: $0.key, value: Double($0.value.count)) }
            .sorted { $0.value > $1.value }
    }

    var recentFatigueSummaries: [CompletedSession] {
        completedSessions
            .sorted { $0.performedOn > $1.performedOn }
            .prefix(5)
            .map { $0 }
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

    var activeRunHasActivity: Bool {
        activeRun.hasActivity
    }

    var activeRunSummary: ProgramRunSummary {
        summary(for: activeRun)
    }

    var archiveOverview: ArchiveOverview {
        let sessions = archivedRuns.flatMap(\.completedSessions)
        return ArchiveOverview(
            archivedProgramCount: archivedRuns.count,
            totalArchivedWorkouts: sessions.count,
            totalArchivedTonnage: sessions.reduce(0) { $0 + $1.summary.totalVolume },
            bestArchivedEstimatedOneRepMax: sessions.compactMap(\.summary.bestEstimatedOneRepMax).max() ?? 0
        )
    }

    var archivedRunSummaries: [ProgramRunSummary] {
        archivedRuns
            .sorted { lhs, rhs in
                let lhsDate = lhs.endedAt ?? lhs.startedAt
                let rhsDate = rhs.endedAt ?? rhs.startedAt
                return lhsDate > rhsDate
            }
            .map { run in
                summary(for: run)
            }
    }

    func summary(for run: ProgramRun) -> ProgramRunSummary {
        let sessions = run.completedSessions
        let adherenceRate = ProgramDefinition.programDays.isEmpty
            ? 0
            : Double(sessions.count) / Double(ProgramDefinition.programDays.count)
        let averageFatigueDelta = sessions.isEmpty
            ? 0
            : sessions.reduce(0) { $0 + $1.fatigue.effortDelta } / Double(sessions.count)

        let liftCallouts = LiftType.allCases.compactMap { lift -> RunLiftCallout? in
            let liftSessions = sessions.filter { $0.programEntry.primaryLift == lift }
            guard !liftSessions.isEmpty else { return nil }

            let bestEstimatedOneRepMax = liftSessions.compactMap(\.summary.bestEstimatedOneRepMax).max() ?? 0
            let bestWorkingWeight = liftSessions
                .flatMap(\.sets)
                .filter { $0.setType == .topSet && $0.completed && !$0.skipped }
                .compactMap(\.weight)
                .max() ?? 0

            return RunLiftCallout(
                lift: lift,
                completedSessions: liftSessions.count,
                bestEstimatedOneRepMax: bestEstimatedOneRepMax,
                bestWorkingWeight: bestWorkingWeight
            )
        }

        return ProgramRunSummary(
            id: run.id,
            startedAt: run.startedAt,
            endedAt: run.endedAt,
            completedWorkoutCount: sessions.count,
            adherenceRate: adherenceRate,
            totalTonnage: sessions.reduce(0) { $0 + $1.summary.totalVolume },
            averageFatigueDelta: averageFatigueDelta,
            recommendationCounts: recommendationCounts(for: sessions),
            liftCallouts: liftCallouts
        )
    }

    func sessions(for run: ProgramRun) -> [CompletedSession] {
        run.completedSessions.sorted { lhs, rhs in
            if lhs.programEntry.week != rhs.programEntry.week {
                return lhs.programEntry.week < rhs.programEntry.week
            }
            return lhs.programEntry.day.weekdayIndex < rhs.programEntry.day.weekdayIndex
        }
    }

    func estimatedOneRepMaxTrend(for run: ProgramRun) -> [AnalyticsPoint] {
        weekOrderedPoints(from: run.completedSessions) { _, sessions in
            sessions.compactMap(\.summary.bestEstimatedOneRepMax).max()
        }
    }

    func weeklyVolumeTrend(for run: ProgramRun) -> [AnalyticsPoint] {
        weekOrderedPoints(from: run.completedSessions) { _, sessions in
            sessions.reduce(0) { $0 + $1.summary.totalVolume }
        }
    }

    func fatigueTimeline(for run: ProgramRun) -> [AnalyticsPoint] {
        weekOrderedPoints(from: run.completedSessions) { _, sessions in
            let deltas = sessions.map(\.fatigue.effortDelta)
            guard !deltas.isEmpty else { return nil }
            return deltas.reduce(0, +) / Double(deltas.count)
        }
    }

    func targetAdjustmentTimeline(for run: ProgramRun) -> [AnalyticsPoint] {
        weekOrderedPoints(from: run.completedSessions) { _, sessions in
            let shifts = sessions.map { $0.fatigue.targetAdjustmentPercent * 100 }
            guard !shifts.isEmpty else { return nil }
            return shifts.reduce(0, +) / Double(shifts.count)
        }
    }

    func select(week: Int, day: TrainingDay) {
        selectedWeek = week
        selectedDay = day
        ensureDraftForSelection()
        persist()
    }

    func updateProgramStartDate(_ date: Date) {
        programStartDate = Calendar.current.startOfDay(for: date)
        activeRun.programStartDate = programStartDate
        lastAutoSelectedDate = nil
        autoSelectTodayIfNeeded()
        persist()
    }

    func updateEstimatedOneRepMax(for lift: LiftType, to value: Double) {
        guard value > 0 else { return }
        var state = liftStates[lift] ?? LiftState.defaults[lift]!
        state.estimatedOneRepMax = value
        state.trainingMax = roundedTrainingMax(from: value)
        liftStates[lift] = state
        regenerateUnfinishedDrafts(for: lift, using: state)
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
        activeRun.completedSessions.removeAll { $0.programEntry.key == entry.key }
        activeRun.completedSessions.append(result.completedSession)
        lastCompletionSummary = result.completedSession
        drafts[entry.key] = WorkoutEngine.makeDraft(for: entry, liftState: result.updatedLiftState, variation: draft.selectedVariation)
        refreshFutureDrafts(for: entry.primaryLift, after: entry, using: result.updatedLiftState)
        persist()
    }

    func dismissCompletionSummary() {
        lastCompletionSummary = nil
    }

    func refreshTodaySelectionIfNeeded() {
        autoSelectTodayIfNeeded()
    }

    func updateLastUsedRestDuration(seconds: Int) {
        lastUsedRestDurationSeconds = max(60, seconds)
        persist()
    }

    func startNewProgram(archiveCurrent: Bool, startDate: Date = .now) {
        let normalizedStartDate = Calendar.current.startOfDay(for: startDate)

        if archiveCurrent, activeRun.hasActivity {
            var archivedRun = activeRun
            archivedRun.endedAt = .now
            archivedRuns.append(archivedRun)
        }

        programStartDate = normalizedStartDate
        selectedWeek = ProgramDefinition.weeks().first ?? 1
        selectedDay = .monday
        lastAutoSelectedDate = nil
        drafts = [:]
        activeRun = ProgramRun(startedAt: normalizedStartDate, programStartDate: normalizedStartDate)
        lastCompletionSummary = nil
        autoSelectTodayIfNeeded(referenceDate: normalizedStartDate)
        ensureDraftForSelection()
        persist()
    }

    func deleteArchivedRun(_ runID: UUID) {
        archivedRuns.removeAll { $0.id == runID }
        persist()
    }

    func archivedRun(with id: UUID) -> ProgramRun? {
        archivedRuns.first { $0.id == id }
    }

    func sessionDate(for entry: ProgramEntry) -> Date {
        sessionDate(for: entry, programStartDate: programStartDate)
    }

    func sessionDate(for entry: ProgramEntry, in run: ProgramRun) -> Date {
        sessionDate(for: entry, programStartDate: run.programStartDate)
    }

    func completedSession(for entry: ProgramEntry) -> CompletedSession? {
        completedSession(for: entry, in: activeRun)
    }

    func completedSession(for entry: ProgramEntry, in run: ProgramRun) -> CompletedSession? {
        run.completedSessions.last { $0.programEntry.key == entry.key }
    }

    private func ensureDraftForSelection() {
        guard let entry = currentEntry else { return }
        if drafts[entry.key] == nil {
            let liftState = liftStates[entry.primaryLift] ?? LiftState.defaults[entry.primaryLift]!
            drafts[entry.key] = WorkoutEngine.makeDraft(for: entry, liftState: liftState, variation: nil)
        }
        persist()
    }

    private func persist() {
        activeRun.programStartDate = programStartDate
        let snapshot = AppSnapshot(
            programStartDate: programStartDate,
            selectedWeek: selectedWeek,
            selectedDay: selectedDay,
            lastAutoSelectedDate: lastAutoSelectedDate,
            lastUsedRestDurationSeconds: lastUsedRestDurationSeconds,
            drafts: drafts,
            activeRun: activeRun,
            archivedRuns: archivedRuns,
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

    private func autoSelectTodayIfNeeded(referenceDate: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let alreadyAutoSelectedToday = lastAutoSelectedDate.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        guard !alreadyAutoSelectedToday, let todayEntry = todayEntry(referenceDate: today) else { return }

        selectedWeek = todayEntry.week
        selectedDay = todayEntry.day
        lastAutoSelectedDate = today
        ensureDraftForSelection()
    }

    private func todayEntry(referenceDate: Date = .now) -> ProgramEntry? {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: referenceDate)
        return ProgramDefinition.programDays.first { entry in
            calendar.isDate(sessionDate(for: entry), inSameDayAs: targetDate)
        }
    }

    private func regenerateUnfinishedDrafts(for lift: LiftType, using liftState: LiftState) {
        for entry in ProgramDefinition.programDays where entry.primaryLift == lift {
            guard completedSession(for: entry) == nil else { continue }
            let variation = drafts[entry.key]?.selectedVariation
            drafts[entry.key] = WorkoutEngine.makeDraft(for: entry, liftState: liftState, variation: variation)
        }
    }

    private func roundedTrainingMax(from estimatedOneRepMax: Double) -> Double {
        let proposedTrainingMax = estimatedOneRepMax * 0.95
        return max(45, (proposedTrainingMax / 5).rounded() * 5)
    }

    private func sessionDate(for entry: ProgramEntry, programStartDate: Date) -> Date {
        let calendar = Calendar.current
        let startWeekday = calendar.component(.weekday, from: programStartDate)
        let offsetToTarget = (entry.day.weekdayIndex - startWeekday + 7) % 7
        let dayOffset = (entry.week - 1) * 7 + offsetToTarget
        return calendar.date(byAdding: .day, value: dayOffset, to: programStartDate) ?? programStartDate
    }

    private func weekOrderedPoints(
        from sessions: [CompletedSession],
        reducer: (Int, [CompletedSession]) -> Double?
    ) -> [AnalyticsPoint] {
        let grouped = Dictionary(grouping: sessions, by: { $0.programEntry.week })
        return grouped.keys.sorted().compactMap { week in
            guard let weekSessions = grouped[week], let value = reducer(week, weekSessions) else { return nil }
            return AnalyticsPoint(order: week, label: "W\(week)", value: value)
        }
    }

    private func recommendationCounts(for sessions: [CompletedSession]) -> [RecommendationCount] {
        let grouped = Dictionary(grouping: sessions, by: \.fatigue.recommendation)
        return EngineRecommendation.allCasesForDashboard.map { recommendation in
            RecommendationCount(recommendation: recommendation, count: grouped[recommendation]?.count ?? 0)
        }
    }

    private func liftSnapshots(for sessions: [CompletedSession]) -> [LiftAnalyticsSnapshot] {
        LiftType.allCases.map { lift in
            let liftSessions = sessions.filter { $0.programEntry.primaryLift == lift }
            let tonnage = liftSessions.reduce(0) { $0 + $1.summary.totalVolume }
            let bestEstimatedOneRepMax = liftSessions.compactMap(\.summary.bestEstimatedOneRepMax).max() ?? liftStates[lift]?.estimatedOneRepMax ?? 0
            let variationCount = liftSessions.filter { !($0.summary.variationUsed ?? "").isEmpty }.count
            let averageFatigueDelta = liftSessions.isEmpty ? 0 : liftSessions.reduce(0) { $0 + $1.fatigue.effortDelta } / Double(liftSessions.count)
            let latestRecommendation = liftSessions.sorted { $0.performedOn > $1.performedOn }.first?.fatigue.recommendation ?? .hold
            return LiftAnalyticsSnapshot(
                lift: lift,
                tonnage: tonnage,
                bestEstimatedOneRepMax: bestEstimatedOneRepMax,
                variationCount: variationCount,
                averageFatigueDelta: averageFatigueDelta,
                latestRecommendation: latestRecommendation
            )
        }
    }
}
