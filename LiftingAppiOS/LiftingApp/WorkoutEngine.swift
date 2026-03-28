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

    static func makeDraft(for entry: ProgramEntry, liftState: LiftState, variation: VariationSelection?) -> SessionDraft {
        let chosenVariation = variation ?? ProgramDefinition.defaultVariationSelection(for: entry.primaryLift)
        let sets = initialSets(for: entry, liftState: liftState, variation: chosenVariation)
        return SessionDraft(programEntry: entry, selectedVariation: chosenVariation, sets: sets)
    }

    static func initialSets(for entry: ProgramEntry, liftState: LiftState, variation: VariationSelection) -> [WorkoutSet] {
        let topWeight = targetWeight(for: entry, liftState: liftState)
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
        let topSetReps = entry.reps

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
            sets.append(defaultVariationSet(for: entry, liftState: liftState, selection: variation, setOrder: sets.count + 1))
        }

        return normalize(sets)
    }

    static func addSet(to draft: SessionDraft, setType: WorkoutSetType, liftState: LiftState) -> SessionDraft {
        var updatedDraft = draft
        let plan = draft.programEntry
        let topWeight = targetWeight(for: plan, liftState: liftState)
        let matchingSetCount = draft.sets.filter { $0.setType == setType }.count

        switch setType {
        case .variation:
            updatedDraft.sets.append(
                defaultVariationSet(
                    for: plan,
                    liftState: liftState,
                    selection: draft.selectedVariation,
                    setOrder: updatedDraft.sets.count + 1
                )
            )
        default:
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
                nil
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
                    exerciseName: plan.primaryLift.displayName,
                    weight: weight,
                    reps: reps
                )
            )
        }

        updatedDraft.sets = normalize(updatedDraft.sets)
        return updatedDraft
    }

    static func completeSession(_ draft: SessionDraft, liftState: LiftState, date: Date = .now) -> SessionCompletionResult {
        let fatigue = assessFatigue(for: draft)
        let adjustedDraft = applyBackoffDecision(to: draft, fatigue: fatigue)
        let summary = makeSummary(for: adjustedDraft)
        let updatedState = updateLiftState(from: liftState, draft: adjustedDraft, fatigue: fatigue, summary: summary, performedOn: date)
        let nextTarget = targetWeight(for: draft.programEntry, liftState: updatedState)

        let completed = CompletedSession(
            id: draft.id,
            programEntry: draft.programEntry,
            performedOn: date,
            variation: draft.selectedVariation.profileName,
            sets: adjustedDraft.sets.sortedForDisplay(),
            fatigue: fatigue,
            summary: summary,
            nextTargetWeight: nextTarget == 0 ? nil : nextTarget
        )

        return SessionCompletionResult(completedSession: completed, updatedLiftState: updatedState)
    }

    static func replayLiftState(from current: LiftState, session: CompletedSession) -> LiftState {
        let topWeight = session.sets
            .filter { $0.completed && !$0.skipped && $0.setType == .topSet }
            .compactMap(\.weight)
            .max()

        return applyLiftStateUpdate(
            current: current,
            topWeight: topWeight,
            fatigue: session.fatigue,
            summary: session.summary,
            performedOn: session.performedOn
        )
    }

    static func targetWeight(for entry: ProgramEntry, liftState: LiftState) -> Double {
        let effectiveOneRepMax = min(liftState.estimatedOneRepMax, liftState.trainingMax / 0.95)
        let adjustedPercent = max(0.82, 1 + liftState.lastTargetAdjustmentPercent)
        return roundToIncrement(effectiveOneRepMax * targetPercent(for: entry) * adjustedPercent)
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

    static func variationSummary(for set: WorkoutSet) -> (straightBarWeight: Double, chainLoad: Double, totalLoad: Double)? {
        guard set.setType == .variation else { return nil }
        let straightBarWeight = set.weight ?? 0
        let chainLoad = set.totalChainLoad
        let totalLoad = straightBarWeight + chainLoad
        return (straightBarWeight, chainLoad, totalLoad)
    }

    static func makeVariationSet(for entry: ProgramEntry, liftState: LiftState, selection: VariationSelection, setOrder: Int) -> WorkoutSet {
        defaultVariationSet(for: entry, liftState: liftState, selection: selection, setOrder: setOrder)
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
                (.warmup, 8, roundToIncrement(topWeight * 0.35)),
                (.ramp, 5, roundToIncrement(topWeight * 0.5))
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
        case .barbellRow:
            [(.warmup, 10, roundToIncrement(topWeight * 0.25)), (.warmup, 6, roundToIncrement(topWeight * 0.45))]
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

    private static func defaultVariationSet(for entry: ProgramEntry, liftState: LiftState, selection: VariationSelection, setOrder: Int) -> WorkoutSet {
        let topWeight = targetWeight(for: entry, liftState: liftState)
        guard let profile = ProgramDefinition.variationProfile(named: selection.profileName, for: entry.primaryLift) else {
            return WorkoutSet(
                setOrder: setOrder,
                setType: .variation,
                exerciseName: selection.profileName,
                weight: roundToIncrement(topWeight * 0.75),
                reps: 8,
                variationProfileName: selection.profileName
            )
        }

        let weight: Double?
        let chainCountPerSide: Int
        let chainUnitWeightPerSide: Double?

        switch profile.loadingMode {
        case .primaryLiftTargetMultiplier(let multiplier):
            weight = roundToIncrement(topWeight * multiplier)
            chainCountPerSide = 0
            chainUnitWeightPerSide = nil
        case .externalLoadOnly:
            weight = 0
            chainCountPerSide = 0
            chainUnitWeightPerSide = nil
        case .basePlusChains(let baseMultiplier, let chainUnitPerSide):
            weight = roundToIncrement(topWeight * baseMultiplier)
            chainCountPerSide = max(0, selection.chainCountPerSide)
            chainUnitWeightPerSide = chainUnitPerSide
        }

        return WorkoutSet(
            setOrder: setOrder,
            setType: .variation,
            exerciseName: profile.name,
            weight: weight,
            reps: entry.plannedType == .deload ? 8 : 8,
            variationProfileName: profile.name,
            chainCountPerSide: chainCountPerSide,
            chainUnitWeightPerSide: chainUnitWeightPerSide
        )
    }

    private static func assessFatigue(for draft: SessionDraft) -> FatigueAssessment {
        let entry = draft.programEntry
        let expectedRampEffort = expectedRampEffort(for: entry)
        let expectedTopSetEffort = expectedTopSetEffort(for: entry)

        let completedRampSets = draft.sets.filter { $0.completed && !$0.skipped && $0.setType == .ramp }
        let completedTopSets = draft.sets.filter { $0.completed && !$0.skipped && $0.setType == .topSet }
        let rampRPEs = completedRampSets.compactMap(\.rpe)
        let topSetRPEs = completedTopSets.compactMap(\.rpe)
        let hasRampEffortData = !rampRPEs.isEmpty
        let hasTopSetEffortData = !topSetRPEs.isEmpty
        let hasAnyEffortData = hasRampEffortData || hasTopSetEffortData

        let actualRampEffort = rampRPEs.average ?? expectedRampEffort
        let actualTopSetEffort = topSetRPEs.average ?? expectedTopSetEffort

        let expectedEffort = (expectedRampEffort * 0.35) + (expectedTopSetEffort * 0.65)
        let actualEffort = weightedActualEffort(ramp: actualRampEffort, top: actualTopSetEffort, completedRampSets: completedRampSets.count, completedTopSets: completedTopSets.count)
        let effortDelta = actualEffort - expectedEffort
        let rampFatigue = actualRampEffort - expectedRampEffort
        let topSetFatigue = actualTopSetEffort - expectedTopSetEffort

        let recommendation: EngineRecommendation
        if !hasAnyEffortData {
            recommendation = .hold
        } else if topSetFatigue >= 1.5 || effortDelta >= 1.25 {
            recommendation = .deload
        } else if topSetFatigue >= 0.75 || rampFatigue >= 0.75 || effortDelta >= 0.6 {
            recommendation = .reduce
        } else {
            recommendation = .hold
        }

        let skipBackoffWork = hasAnyEffortData
            && draft.sets.contains(where: { $0.setType == .backoff })
            && (recommendation != .hold || topSetFatigue >= 0.5 || rampFatigue >= 1.0)
        let targetAdjustmentPercent: Double
        if recommendation == .deload {
            targetAdjustmentPercent = -0.08
        } else if recommendation == .reduce {
            targetAdjustmentPercent = -0.03
        } else if hasAnyEffortData && effortDelta <= -0.35 {
            targetAdjustmentPercent = 0.02
        } else {
            targetAdjustmentPercent = 0
        }

        let decisionReason: String
        if !hasAnyEffortData {
            decisionReason = "No RPE data was recorded, so progression stays neutral and backoff work is not automatically skipped."
        } else if skipBackoffWork {
            decisionReason = recommendation == .deload
                ? "Backoff work was skipped because working-set effort came in well above the expected target."
                : "Backoff work was skipped because ramp or working-set effort came in above the expected target."
        } else {
            decisionReason = "Backoff work stays in plan because recorded effort stayed close to the expected target."
        }

        return FatigueAssessment(
            expectedRampEffort: expectedRampEffort,
            expectedTopSetEffort: expectedTopSetEffort,
            actualRampEffort: actualRampEffort,
            actualTopSetEffort: actualTopSetEffort,
            expectedEffort: expectedEffort,
            actualEffort: actualEffort,
            effortDelta: effortDelta,
            rampFatigue: rampFatigue,
            topSetFatigue: topSetFatigue,
            skipBackoffWork: skipBackoffWork,
            targetAdjustmentPercent: targetAdjustmentPercent,
            backoffDecisionReason: decisionReason,
            recommendation: recommendation
        )
    }

    private static func updateLiftState(from current: LiftState, draft: SessionDraft, fatigue: FatigueAssessment, summary: SessionSummary, performedOn: Date) -> LiftState {
        let topWeight = draft.sets.filter { $0.completed && $0.setType == .topSet }.compactMap(\.weight).max()
        return applyLiftStateUpdate(
            current: current,
            topWeight: topWeight,
            fatigue: fatigue,
            summary: summary,
            performedOn: performedOn
        )
    }

    private static func makeSummary(for draft: SessionDraft) -> SessionSummary {
        let sortedSets = draft.sets.sortedForDisplay()
        let bestEstimatedOneRepMax = sortedSets
            .filter { !$0.skipped }
            .compactMap { estimateOneRepMax(weight: $0.totalDisplayedLoad > 0 ? $0.totalDisplayedLoad : nil, reps: $0.reps) }
            .max()

        let totalVolume = sortedSets.reduce(0) { $0 + $1.volumeContribution }
        let completedSetCount = sortedSets.filter { $0.completed && !$0.skipped }.count
        let variation = sortedSets.contains(where: { $0.setType == .variation && $0.completed && !$0.skipped }) ? draft.selectedVariation.profileName : nil

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

    private static func expectedRampEffort(for entry: ProgramEntry) -> Double {
        switch entry.phase {
        case .volume: 6.0
        case .strength: 6.8
        case .peak: 7.4
        case .taper: 5.8
        }
    }

    private static func expectedTopSetEffort(for entry: ProgramEntry) -> Double {
        switch entry.plannedType {
        case .deload:
            return 6.0
        case .opener:
            return 7.8
        case .maxSingle:
            return 8.8
        case .workingSets:
            return defaultExpectedEffort(for: entry) + (entry.reps <= 2 ? 0.4 : 0)
        }
    }

    private static func weightedActualEffort(ramp: Double, top: Double, completedRampSets: Int, completedTopSets: Int) -> Double {
        switch (completedRampSets > 0, completedTopSets > 0) {
        case (true, true):
            return (ramp * 0.35) + (top * 0.65)
        case (true, false):
            return ramp
        case (false, true):
            return top
        case (false, false):
            return top
        }
    }

    private static func applyBackoffDecision(to draft: SessionDraft, fatigue: FatigueAssessment) -> SessionDraft {
        guard fatigue.skipBackoffWork else { return draft }

        var updatedDraft = draft
        updatedDraft.sets = updatedDraft.sets.map { set in
            guard set.setType == .backoff, !set.completed else { return set }
            var updated = set
            updated.skipped = true
            return updated
        }
        return updatedDraft
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

    private static func applyLiftStateUpdate(
        current: LiftState,
        topWeight: Double?,
        fatigue: FatigueAssessment,
        summary: SessionSummary,
        performedOn: Date
    ) -> LiftState {
        var updated = current
        let bestEstimatedOneRepMax = summary.bestEstimatedOneRepMax ?? current.estimatedOneRepMax
        let targetTrainingMax = roundToIncrement(bestEstimatedOneRepMax * 0.94)

        updated.estimatedOneRepMax = round((current.estimatedOneRepMax * 0.7) + (bestEstimatedOneRepMax * 0.3))
        updated.lastGoodWorkingWeight = topWeight ?? current.lastGoodWorkingWeight
        updated.lastRecommendation = fatigue.recommendation
        updated.lastTargetAdjustmentPercent = fatigue.targetAdjustmentPercent
        updated.fatigueScore = min(10, max(0, (current.fatigueScore * 0.55) + max(0, fatigue.effortDelta) * 2 + max(0, fatigue.topSetFatigue) * 1.25))
        if fatigue.recommendation == .hold {
            updated.trainingMax = roundToIncrement(max(45, current.trainingMax * 0.9 + targetTrainingMax * 0.1 + (fatigue.targetAdjustmentPercent > 0 ? 2.5 : 0)))
            updated.lastSuccessfulSessionDate = performedOn
        } else if fatigue.recommendation == .reduce {
            updated.trainingMax = roundToIncrement(max(45, current.trainingMax * 0.92 + targetTrainingMax * 0.08 - 5))
        } else {
            updated.trainingMax = roundToIncrement(max(45, current.trainingMax * 0.88 + targetTrainingMax * 0.12 - 10))
        }

        return updated
    }
}

private extension Sequence where Element == Double {
    var average: Double? {
        let values = Array(self)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
