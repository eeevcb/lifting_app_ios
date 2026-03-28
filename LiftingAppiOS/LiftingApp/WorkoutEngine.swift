import Foundation

struct SessionCompletionResult {
    let completedSession: CompletedSession
    let updatedLiftState: LiftState
}

enum WorkoutEngine {
    private static let targetPercentByPlan: [PlannedSetType: [String: Double]] = [
        .workingSets: [
            "4x8": 0.67,
            "5x5": 0.73,
            "3x3": 0.82,
            "2x2": 0.88
        ]
    ]

    static func makeDraft(for entry: ProgramEntry, liftState: LiftState, variation: String?) -> SessionDraft {
        let chosenVariation = variation ?? ProgramDefinition.variationOptions[entry.primaryLift]?.first ?? ""
        let sets = initialSets(for: entry, liftState: liftState, variation: chosenVariation)
        return SessionDraft(programEntry: entry, selectedVariation: chosenVariation, sets: sets)
    }

    static func initialSets(for entry: ProgramEntry, liftState: LiftState, variation: String) -> [WorkoutSet] {
        let topWeight = targetWeight(for: entry, estimatedOneRepMax: liftState.estimatedOneRepMax)
        let warmups = warmupScheme(for: entry.primaryLift, topWeight: topWeight, plannedReps: entry.reps, plannedType: entry.plannedType)

        var sets: [WorkoutSet] = warmups.enumerated().map { index, scheme in
            WorkoutSet(
                setOrder: index + 1,
                setType: scheme.type,
                exerciseName: entry.primaryLift.displayName,
                weight: scheme.weight,
                reps: scheme.reps
            )
        }

        let topSetCount = entry.sets
        let topSetReps = entry.plannedType == .deload ? 0 : entry.reps

        for _ in 0..<topSetCount {
            sets.append(
                WorkoutSet(
                    setOrder: sets.count + 1,
                    setType: .topSet,
                    exerciseName: entry.primaryLift.displayName,
                    weight: topWeight == 0 ? nil : topWeight,
                    reps: topSetReps
                )
            )
        }

        if shouldAddDefaultBackoff(for: entry) {
            sets.append(
                WorkoutSet(
                    setOrder: sets.count + 1,
                    setType: .backoff,
                    exerciseName: entry.primaryLift.displayName,
                    weight: roundToIncrement(topWeight * 0.9),
                    reps: max(2, entry.reps)
                )
            )
        }

        if shouldAddDefaultVariation(for: entry) {
            sets.append(
                WorkoutSet(
                    setOrder: sets.count + 1,
                    setType: .variation,
                    exerciseName: variation,
                    weight: roundToIncrement(topWeight * 0.75),
                    reps: 8
                )
            )
        }

        return normalize(sets)
    }

    static func addSet(to draft: SessionDraft, setType: WorkoutSetType, liftState: LiftState) -> SessionDraft {
        var updatedDraft = draft
        let plan = draft.programEntry
        let topWeight = targetWeight(for: plan, estimatedOneRepMax: liftState.estimatedOneRepMax)
        let matchingSetCount = draft.sets.filter { $0.setType == setType }.count

        let weight: Double? = switch setType {
        case .warmup:
            roundToIncrement(topWeight * (0.3 + Double(matchingSetCount) * 0.1))
        case .ramp:
            roundToIncrement(topWeight * (0.7 + Double(matchingSetCount) * 0.08))
        case .topSet:
            topWeight
        case .backoff:
            roundToIncrement(topWeight * 0.9)
        case .variation:
            roundToIncrement(topWeight * 0.75)
        }

        let reps: Int? = switch setType {
        case .warmup: 8
        case .ramp: max(1, plan.reps - 1)
        case .topSet: plan.reps
        case .backoff: max(2, plan.reps)
        case .variation: 8
        }

        updatedDraft.sets.append(
            WorkoutSet(
                setOrder: updatedDraft.sets.count + 1,
                setType: setType,
                exerciseName: setType == .variation ? draft.selectedVariation : plan.primaryLift.displayName,
                weight: weight,
                reps: reps
            )
        )
        updatedDraft.sets = normalize(updatedDraft.sets)
        return updatedDraft
    }

    static func completeSession(_ draft: SessionDraft, liftState: LiftState, date: Date = .now) -> SessionCompletionResult {
        let fatigue = assessFatigue(for: draft)
        let summary = makeSummary(for: draft)
        let updatedState = updateLiftState(from: liftState, draft: draft, fatigue: fatigue, summary: summary, performedOn: date)
        let nextTarget = targetWeight(for: draft.programEntry, estimatedOneRepMax: updatedState.estimatedOneRepMax)

        let completed = CompletedSession(
            id: draft.id,
            programEntry: draft.programEntry,
            performedOn: date,
            variation: draft.selectedVariation,
            sets: draft.sets.sortedForDisplay(),
            fatigue: fatigue,
            summary: summary,
            nextTargetWeight: nextTarget == 0 ? nil : nextTarget
        )

        return SessionCompletionResult(completedSession: completed, updatedLiftState: updatedState)
    }

    static func targetWeight(for entry: ProgramEntry, estimatedOneRepMax: Double) -> Double {
        guard estimatedOneRepMax > 0 else { return 0 }
        return roundToIncrement(estimatedOneRepMax * targetPercent(for: entry))
    }

    static func targetPercent(for entry: ProgramEntry) -> Double {
        switch entry.plannedType {
        case .workingSets:
            return targetPercentByPlan[.workingSets]?["\(entry.sets)x\(entry.reps)"] ?? 0.75
        case .maxSingle:
            return 0.94
        case .opener:
            return 0.9
        case .deload:
            return 0.6
        }
    }

    static func estimateOneRepMax(weight: Double?, reps: Int?) -> Double? {
        guard let weight, let reps, weight > 0, reps > 0 else { return nil }
        return round(weight * (1 + Double(reps) / 30))
    }

    private static func shouldAddDefaultBackoff(for entry: ProgramEntry) -> Bool {
        entry.plannedType == .workingSets && entry.reps <= 5 && entry.phase != .taper
    }

    private static func shouldAddDefaultVariation(for entry: ProgramEntry) -> Bool {
        entry.plannedType == .deload || entry.primaryLift == .shoulderPress
    }

    private static func warmupScheme(for lift: LiftType, topWeight: Double, plannedReps: Int, plannedType: PlannedSetType) -> [(type: WorkoutSetType, reps: Int, weight: Double)] {
        guard topWeight > 0 else { return [] }

        if plannedType == .deload {
            return [
                (.warmup, 8, roundToIncrement(topWeight * 0.45)),
                (.ramp, 3, roundToIncrement(topWeight * 0.7))
            ]
        }

        let base: [(WorkoutSetType, Int, Double)] = switch lift {
        case .squat:
            [(.warmup, 8, roundToIncrement(topWeight * 0.3)), (.warmup, 5, roundToIncrement(topWeight * 0.5))]
        case .bench:
            [(.warmup, 10, roundToIncrement(topWeight * 0.25)), (.warmup, 6, roundToIncrement(topWeight * 0.45))]
        case .deadlift:
            [(.warmup, 6, roundToIncrement(topWeight * 0.35)), (.warmup, 4, roundToIncrement(topWeight * 0.55))]
        case .shoulderPress:
            [(.warmup, 10, roundToIncrement(topWeight * 0.25)), (.warmup, 5, roundToIncrement(topWeight * 0.5))]
        }

        let ramps: [(WorkoutSetType, Int, Double)]
        if plannedType == .maxSingle || plannedType == .opener {
            ramps = [(.ramp, 2, roundToIncrement(topWeight * 0.7)), (.ramp, 1, roundToIncrement(topWeight * 0.85)), (.ramp, 1, roundToIncrement(topWeight * 0.93))]
        } else if plannedReps <= 2 {
            ramps = [(.ramp, 3, roundToIncrement(topWeight * 0.7)), (.ramp, 1, roundToIncrement(topWeight * 0.85))]
        } else if plannedReps == 3 {
            ramps = [(.ramp, 2, roundToIncrement(topWeight * 0.72)), (.ramp, 1, roundToIncrement(topWeight * 0.86))]
        } else {
            ramps = [(.ramp, 3, roundToIncrement(topWeight * 0.7))]
        }

        return base + ramps
    }

    private static func assessFatigue(for draft: SessionDraft) -> FatigueAssessment {
        let topAndRampSets = draft.sets.filter { !$0.skipped && $0.completed && ($0.setType == .ramp || $0.setType == .topSet) }
        let averageRPE = topAndRampSets.compactMap(\.rpe).average ?? defaultExpectedEffort(for: draft.programEntry)
        let rampRPE = draft.sets.filter { $0.completed && $0.setType == .ramp }.compactMap(\.rpe).average ?? averageRPE
        let topSetRPE = draft.sets.filter { $0.completed && $0.setType == .topSet }.compactMap(\.rpe).average ?? averageRPE
        let expectedEffort = defaultExpectedEffort(for: draft.programEntry)
        let fatigueDelta = max(0, averageRPE - expectedEffort)

        let recommendation: EngineRecommendation
        if fatigueDelta >= 2 || topSetRPE >= 9.5 {
            recommendation = .deload
        } else if fatigueDelta >= 1 || rampRPE >= 8.5 {
            recommendation = .reduce
        } else {
            recommendation = .hold
        }

        return FatigueAssessment(
            expectedEffort: expectedEffort,
            actualEffort: averageRPE,
            rampFatigue: max(0, rampRPE - expectedEffort),
            topSetFatigue: max(0, topSetRPE - expectedEffort),
            skipBackoffWork: recommendation != .hold,
            recommendation: recommendation
        )
    }

    private static func updateLiftState(from current: LiftState, draft: SessionDraft, fatigue: FatigueAssessment, summary: SessionSummary, performedOn: Date) -> LiftState {
        var updated = current
        let bestEstimatedOneRepMax = summary.bestEstimatedOneRepMax ?? current.estimatedOneRepMax
        let topWeight = draft.sets.filter { $0.completed && $0.setType == .topSet }.compactMap(\.weight).max()

        updated.estimatedOneRepMax = round((current.estimatedOneRepMax * 0.7) + (bestEstimatedOneRepMax * 0.3))
        updated.lastGoodWorkingWeight = topWeight ?? current.lastGoodWorkingWeight
        updated.lastRecommendation = fatigue.recommendation
        updated.fatigueScore = min(10, max(0, (current.fatigueScore * 0.6) + (fatigue.actualEffort - fatigue.expectedEffort) * 1.4))
        if fatigue.recommendation == .hold {
            updated.trainingMax = roundToIncrement(current.trainingMax * 0.98 + updated.estimatedOneRepMax * 0.95 * 0.02)
            updated.lastSuccessfulSessionDate = performedOn
        } else if fatigue.recommendation == .reduce {
            updated.trainingMax = roundToIncrement(max(current.trainingMax * 0.97, current.trainingMax - 10))
        } else {
            updated.trainingMax = roundToIncrement(max(current.trainingMax * 0.93, current.trainingMax - 20))
        }

        return updated
    }

    private static func makeSummary(for draft: SessionDraft) -> SessionSummary {
        let sortedSets = draft.sets.sortedForDisplay()
        let bestEstimatedOneRepMax = sortedSets
            .filter { !$0.skipped }
            .compactMap { estimateOneRepMax(weight: $0.weight, reps: $0.reps) }
            .max()

        let totalVolume = sortedSets.reduce(0) { $0 + $1.volumeContribution }
        let completedSetCount = sortedSets.filter { $0.completed && !$0.skipped }.count
        let variation = sortedSets.contains(where: { $0.setType == .variation && $0.completed && !$0.skipped }) ? draft.selectedVariation : nil

        return SessionSummary(
            totalVolume: totalVolume,
            bestEstimatedOneRepMax: bestEstimatedOneRepMax,
            completedSetCount: completedSetCount,
            variationUsed: variation
        )
    }

    private static func defaultExpectedEffort(for entry: ProgramEntry) -> Double {
        switch entry.phase {
        case .volume: 7.0
        case .strength: 7.8
        case .peak: 8.5
        case .taper: 6.5
        }
    }

    private static func roundToIncrement(_ value: Double, increment: Double = 5) -> Double {
        guard value > 0 else { return 0 }
        return max(increment, (value / increment).rounded() * increment)
    }

    private static func normalize(_ sets: [WorkoutSet]) -> [WorkoutSet] {
        sets.sortedForDisplay().enumerated().map { index, set in
            var updated = set
            updated.setOrder = index + 1
            return updated
        }
    }
}

private extension Sequence where Element == Double {
    var average: Double? {
        let values = Array(self)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
