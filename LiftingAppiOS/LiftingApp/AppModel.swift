import Foundation
import Observation

@Observable
final class AppModel {
    var selectedTab: AppTab = .program
    var programStartDate: Date
    var selectedWeek: Int
    var selectedDay: TrainingDay
    var lastAutoSelectedDate: Date?
    var lastUsedRestDurationSeconds: Int
    var autoStartRestTimerOnCompletion: Bool
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
            autoStartRestTimerOnCompletion = snapshot.autoStartRestTimerOnCompletion
            drafts = snapshot.drafts
            activeRun = snapshot.activeRun
            archivedRuns = snapshot.archivedRuns
            liftStates = Self.normalizedLiftStates(snapshot.liftStates)
        } else {
            let defaultStartDate = ProgramDefinition.defaultStartDate
            programStartDate = defaultStartDate
            selectedWeek = ProgramDefinition.weeks().first ?? 1
            selectedDay = .friday
            lastAutoSelectedDate = nil
            lastUsedRestDurationSeconds = 180
            autoStartRestTimerOnCompletion = true
            drafts = [:]
            activeRun = ProgramRun(startedAt: defaultStartDate, programStartDate: defaultStartDate)
            archivedRuns = []
            liftStates = LiftState.defaults
        }

        lastCompletionSummary = nil
        activeRun.programStartDate = programStartDate
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
        return liftStates[currentEntry.primaryLift] ?? LiftState.defaults[currentEntry.primaryLift]
    }

    var currentDraft: SessionDraft? {
        guard let currentEntry else { return nil }
        return drafts[currentEntry.key]
    }

    var currentCompletedSession: CompletedSession? {
        guard let currentEntry else { return nil }
        return completedSession(for: currentEntry)
    }

    var isCurrentWorkoutFinished: Bool {
        currentCompletedSession != nil
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
            bestEstimatedOneRepMax: draft.sets
                .filter { $0.setType == .topSet && !$0.skipped }
                .compactMap { set in
                    WorkoutEngine.estimateOneRepMax(weight: set.totalDisplayedLoad > 0 ? set.totalDisplayedLoad : nil, reps: set.reps)
                }
                .max(),
            completedSetCount: draft.sets.filter { $0.completed && !$0.skipped }.count,
            variationUsed: actualVariationName(from: draft.sets, fallback: nil)
        )
    }

    var currentTargetWeight: Double? {
        guard let draft = currentDraft else { return nil }
        let target = draft.sets
            .filter { $0.setType == .topSet }
            .compactMap(\.weight)
            .max() ?? 0
        return target == 0 ? nil : target
    }

    var currentEngineStatusText: String {
        if let session = currentCompletedSession {
            return session.fatigue.recommendation.displayName
        }

        guard let draft = currentDraft else { return "Pending" }

        if let previewRecommendation = previewRecommendation(for: draft) {
            return previewRecommendation.displayName
        }

        return "Pending"
    }

    var currentTargetShiftPercent: Double {
        if let session = currentCompletedSession {
            return session.fatigue.targetAdjustmentPercent
        }

        return currentDraft?.appliedTargetAdjustmentPercent ?? 0
    }

    var estimatedOneRepMaxTrend: [AnalyticsPoint] {
        weekOrderedPoints(from: completedSessions) { _, sessions in
            sessions.compactMap(\.summary.bestEstimatedOneRepMax).max()
        }
    }

    var estimatedOneRepMaxTrendByLift: [LiftTrendSeries] {
        liftSpecificTrend(from: completedSessions, lifts: [.squat, .bench, .deadlift]) { _, sessions in
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
        let grouped = Dictionary(grouping: completedSessions.compactMap { session -> String? in
            actualVariationName(from: session.sets, fallback: session.variation)
        }, by: { $0 })
        return grouped
            .map { AnalyticsPoint(order: $0.value.count, label: $0.key, value: Double($0.value.count)) }
            .sorted { ($0.value ?? 0) > ($1.value ?? 0) }
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
        let bestByLift = LiftType.allCases.compactMap { lift -> ArchivedLiftBest? in
            let best = sessions
                .filter { $0.programEntry.primaryLift == lift }
                .compactMap(\.summary.bestEstimatedOneRepMax)
                .max() ?? 0
            guard best > 0 else { return nil }
            return ArchivedLiftBest(lift: lift, bestEstimatedOneRepMax: best)
        }
        return ArchiveOverview(
            archivedProgramCount: archivedRuns.count,
            totalArchivedWorkouts: sessions.count,
            totalArchivedTonnage: sessions.reduce(0) { $0 + $1.summary.totalVolume },
            bestArchivedEstimatedOneRepMax: sessions.compactMap(\.summary.bestEstimatedOneRepMax).max() ?? 0,
            bestEstimatedOneRepMaxByLift: bestByLift
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

    func estimatedOneRepMaxTrendByLift(for run: ProgramRun) -> [LiftTrendSeries] {
        liftSpecificTrend(from: run.completedSessions, lifts: [.squat, .bench, .deadlift]) { _, sessions in
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
        persist()
    }

    func updateEstimatedOneRepMax(for lift: LiftType, to value: Double) {
        guard value > 0 else { return }
        var state = liftStates[lift] ?? LiftState.defaults[lift]!
        let roundedEstimatedOneRepMax = roundToIncrement(value)
        state.estimatedOneRepMax = roundedEstimatedOneRepMax
        state.trainingMax = min(roundedTrainingMax(from: roundedEstimatedOneRepMax), roundedEstimatedOneRepMax)
        liftStates[lift] = state
        regenerateUnfinishedDrafts(for: lift, using: state)
        persist()
    }

    func updateVariation(for setID: UUID, to profileName: String) {
        guard let currentEntry, var draft = drafts[currentEntry.key] else { return }
        guard let profile = ProgramDefinition.variationProfile(named: profileName, for: currentEntry.primaryLift) else { return }
        guard let index = draft.sets.firstIndex(where: { $0.id == setID }) else { return }
        let liftState = currentLiftState ?? LiftState.defaults[currentEntry.primaryLift]!
        let currentSet = draft.sets[index]
        let selection = ProgramDefinition.defaultSelection(for: profile)
        let regeneratedSet = WorkoutEngine.makeVariationSet(
            for: currentEntry,
            liftState: liftState,
            selection: selection,
            setOrder: currentSet.setOrder
        )

        draft.sets[index].exerciseName = regeneratedSet.exerciseName
        draft.sets[index].weight = regeneratedSet.weight
        draft.sets[index].reps = regeneratedSet.reps
        draft.sets[index].rpe = nil
        draft.sets[index].completed = false
        draft.sets[index].skipped = false
        draft.sets[index].variationProfileName = regeneratedSet.variationProfileName
        draft.sets[index].chainCountPerSide = regeneratedSet.chainCountPerSide
        draft.sets[index].chainUnitWeightPerSide = regeneratedSet.chainUnitWeightPerSide
        draft.sets = draft.sets.sortedForDisplay().enumerated().map { index, set in
            var reordered = set
            reordered.setOrder = index + 1
            return reordered
        }

        drafts[currentEntry.key] = draft
        persist()
    }

    func updateSet(_ setID: UUID, mutate: (inout WorkoutSet) -> Void) {
        guard let currentEntry, var draft = drafts[currentEntry.key] else { return }
        guard let index = draft.sets.firstIndex(where: { $0.id == setID }) else { return }
        mutate(&draft.sets[index])
        draft.sets = draft.sets.sortedForDisplay().enumerated().map { index, set in
            var reordered = set
            reordered.setOrder = index + 1
            return reordered
        }
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
        guard completedSession(for: entry) == nil else { return }
        let result = WorkoutEngine.completeSession(draft, liftState: liftState)
        liftStates[entry.primaryLift] = result.updatedLiftState
        activeRun.completedSessions.removeAll { $0.programEntry.key == entry.key }
        activeRun.completedSessions.append(result.completedSession)
        lastCompletionSummary = result.completedSession
        drafts[entry.key] = SessionDraft(
            id: draft.id,
            programEntry: draft.programEntry,
            selectedVariation: draft.selectedVariation,
            appliedTargetAdjustmentPercent: draft.appliedTargetAdjustmentPercent,
            sets: result.completedSession.sets,
            generatedAt: .now
        )
        refreshFutureDrafts(for: entry.primaryLift, after: entry, using: result.updatedLiftState)
        persist()
    }

    func reviewCurrentWorkoutSummary() {
        lastCompletionSummary = currentCompletedSession
    }

    func reopenCurrentWorkout() {
        guard let entry = currentEntry else { return }
        guard let session = completedSession(for: entry) else { return }
        let existingSelection = drafts[entry.key]?.selectedVariation
            ?? variationSelection(from: session)
            ?? ProgramDefinition.defaultVariationSelection(for: entry.primaryLift)

        activeRun.completedSessions.removeAll { $0.id == session.id }
        if lastCompletionSummary?.id == session.id {
            lastCompletionSummary = nil
        }

        rebuildLiftStatesFromActiveRun()
        rebuildDraftsAfterSessionChange(reopenedEntry: entry, reopenedSession: session, reopenedSelection: existingSelection)
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

    func updateAutoStartRestTimerOnCompletion(_ enabled: Bool) {
        autoStartRestTimerOnCompletion = enabled
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
        selectedTab = .workout
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
            drafts[entry.key] = makeDraft(for: entry, liftState: liftState, variation: nil)
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
            autoStartRestTimerOnCompletion: autoStartRestTimerOnCompletion,
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

            drafts[key] = makeDraft(for: draft.programEntry, liftState: liftState, variation: draft.selectedVariation)
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
            if var existingDraft = drafts[entry.key] {
                let regeneratedDraft = makeDraft(for: entry, liftState: liftState, variation: existingDraft.selectedVariation)
                existingDraft.sets = mergePreservingCompletedSets(existing: existingDraft.sets, regenerated: regeneratedDraft.sets)
                existingDraft.appliedTargetAdjustmentPercent = regeneratedDraft.appliedTargetAdjustmentPercent
                existingDraft.generatedAt = regeneratedDraft.generatedAt
                drafts[entry.key] = existingDraft
            } else {
                drafts[entry.key] = makeDraft(for: entry, liftState: liftState, variation: nil)
            }
        }
    }

    private func roundedTrainingMax(from estimatedOneRepMax: Double) -> Double {
        let proposedTrainingMax = estimatedOneRepMax * 0.95
        return min(roundToIncrement(max(45, proposedTrainingMax)), roundToIncrement(estimatedOneRepMax))
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
        return ProgramDefinition.weeks().map { week in
            let weekSessions = grouped[week] ?? []
            let value = weekSessions.isEmpty ? nil : reducer(week, weekSessions)
            return AnalyticsPoint(order: week, label: "W\(week)", value: value)
        }
    }

    private func liftSpecificTrend(
        from sessions: [CompletedSession],
        lifts: [LiftType],
        reducer: (Int, [CompletedSession]) -> Double?
    ) -> [LiftTrendSeries] {
        lifts.map { lift in
            LiftTrendSeries(
                lift: lift,
                points: weekOrderedPoints(from: sessions.filter { $0.programEntry.primaryLift == lift }, reducer: reducer)
            )
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
            let variationCount = liftSessions.filter { actualVariationName(from: $0.sets, fallback: $0.summary.variationUsed) != nil }.count
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

    private func mergePreservingCompletedSets(existing: [WorkoutSet], regenerated: [WorkoutSet]) -> [WorkoutSet] {
        let existingByOrder = Dictionary(uniqueKeysWithValues: existing.map { ($0.setOrder, $0) })
        return regenerated.map { regeneratedSet in
            guard let existingSet = existingByOrder[regeneratedSet.setOrder] else { return regeneratedSet }
            if existingSet.completed || existingSet.skipped {
                return existingSet
            }
            return regeneratedSet
        }
    }

    private func rebuildLiftStatesFromActiveRun() {
        var rebuiltStates = LiftState.defaults
        let orderedSessions = activeRun.completedSessions.sorted { lhs, rhs in
            if lhs.programEntry.week != rhs.programEntry.week {
                return lhs.programEntry.week < rhs.programEntry.week
            }
            if lhs.programEntry.day.weekdayIndex != rhs.programEntry.day.weekdayIndex {
                return lhs.programEntry.day.weekdayIndex < rhs.programEntry.day.weekdayIndex
            }
            return lhs.performedOn < rhs.performedOn
        }

        for session in orderedSessions {
            let lift = session.programEntry.primaryLift
            let current = rebuiltStates[lift] ?? LiftState.defaults[lift]!
            rebuiltStates[lift] = WorkoutEngine.replayLiftState(from: current, session: session)
        }

        liftStates = rebuiltStates
    }

    private func rebuildDraftsAfterSessionChange(reopenedEntry: ProgramEntry, reopenedSession: CompletedSession, reopenedSelection: VariationSelection) {
        let existingSelections = drafts.mapValues(\.selectedVariation)
        var rebuiltDrafts: [String: SessionDraft] = [:]

        for entry in ProgramDefinition.programDays {
            guard completedSession(for: entry) == nil else { continue }
            let liftState = liftStates[entry.primaryLift] ?? LiftState.defaults[entry.primaryLift]!
            let selection = existingSelections[entry.key]
            rebuiltDrafts[entry.key] = makeDraft(for: entry, liftState: liftState, variation: selection)
        }

        drafts = rebuiltDrafts
        drafts[reopenedEntry.key] = SessionDraft(
            id: UUID(),
            programEntry: reopenedEntry,
            selectedVariation: reopenedSelection,
            appliedTargetAdjustmentPercent: reopenedSession.fatigue.targetAdjustmentPercent,
            sets: reopenedSession.sets,
            generatedAt: .now
        )
    }

    private func makeDraft(for entry: ProgramEntry, liftState: LiftState, variation: VariationSelection?) -> SessionDraft {
        let adjustmentPercent = pendingTargetAdjustmentPercent(for: entry, liftState: liftState)
        return WorkoutEngine.makeDraft(
            for: entry,
            liftState: liftState,
            variation: variation,
            targetAdjustmentPercent: adjustmentPercent
        )
    }

    private func pendingTargetAdjustmentPercent(for entry: ProgramEntry, liftState: LiftState) -> Double {
        let pendingAdjustment = liftState.pendingTargetAdjustmentPercent
        guard pendingAdjustment != 0 else { return 0 }

        let firstUnfinishedEntry = ProgramDefinition.programDays.first { candidate in
            candidate.primaryLift == entry.primaryLift && completedSession(for: candidate) == nil
        }

        guard firstUnfinishedEntry?.key == entry.key else { return 0 }
        return pendingAdjustment
    }

    private func actualVariationName(from sets: [WorkoutSet], fallback: String?) -> String? {
        let variationNames = Array(Set(
            sets
                .filter { $0.setType == .variation && $0.completed && !$0.skipped }
                .compactMap { $0.variationProfileName ?? $0.exerciseName }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )).sorted()
        if !variationNames.isEmpty {
            return variationNames.joined(separator: ", ")
        }

        let trimmedFallback = (fallback ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedFallback.isEmpty ? nil : trimmedFallback
    }

    private func variationSelection(from session: CompletedSession) -> VariationSelection? {
        guard let variationSet = session.sets.first(where: { $0.setType == .variation }) else { return nil }
        let profileName = variationSet.variationProfileName ?? variationSet.exerciseName
        return VariationSelection(profileName: profileName, chainCountPerSide: variationSet.chainCountPerSide)
    }

    private func previewRecommendation(for draft: SessionDraft) -> EngineRecommendation? {
        let adjustment = draft.appliedTargetAdjustmentPercent
        if adjustment <= -0.08 {
            return .deload
        }
        if adjustment < 0 {
            return .reduce
        }
        if adjustment > 0 {
            return .hold
        }
        return nil
    }

    private static func normalizedLiftStates(_ states: [LiftType: LiftState]) -> [LiftType: LiftState] {
        var normalized = LiftState.defaults
        for (lift, state) in states {
            var updated = state
            updated.estimatedOneRepMax = roundToIncrement(max(45, updated.estimatedOneRepMax))
            updated.trainingMax = min(roundToIncrement(max(45, updated.trainingMax)), updated.estimatedOneRepMax)
            normalized[lift] = updated
        }
        return normalized
    }

    private static func roundToIncrement(_ value: Double, increment: Double = 5) -> Double {
        guard value > 0 else { return 0 }
        return max(increment, (value / increment).rounded() * increment)
    }
}
