import Foundation

enum AppTab: Hashable {
    case workout
    case dashboard
    case program
    case archive
}

enum LiftType: String, CaseIterable, Codable, Hashable, Identifiable {
    case squat
    case bench
    case shoulderPress
    case deadlift
    case barbellRow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squat: "Squat"
        case .bench: "Bench"
        case .shoulderPress: "Shoulder Press"
        case .deadlift: "Deadlift"
        case .barbellRow: "Barbell Row"
        }
    }
}

enum TrainingDay: String, CaseIterable, Codable, Hashable, Identifiable {
    case monday = "Monday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: "Mon"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        }
    }

    var weekdayIndex: Int {
        switch self {
        case .monday: 2
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        }
    }
}

enum PlannedSetType: String, Codable, Hashable {
    case workingSets
    case maxSingle
    case opener
    case deload
}

enum TrainingPhase: String, Codable, Hashable {
    case volume
    case strength
    case peak
    case taper
}

enum WorkoutSetType: String, CaseIterable, Codable, Hashable, Identifiable {
    case warmup
    case ramp
    case topSet
    case backoff
    case variation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmup: "Warmup"
        case .ramp: "Ramp"
        case .topSet: "Working Set"
        case .backoff: "Backoff"
        case .variation: "Variation"
        }
    }

    var sortIndex: Int {
        switch self {
        case .warmup: 0
        case .ramp: 1
        case .topSet: 2
        case .backoff: 3
        case .variation: 4
        }
    }
}

enum EngineRecommendation: String, Codable, Hashable {
    case hold
    case reduce
    case deload

    var displayName: String {
        switch self {
        case .hold:
            "Progression"
        case .reduce:
            "Reduce"
        case .deload:
            "Deload"
        }
    }
}

extension EngineRecommendation {
    static let allCasesForDashboard: [EngineRecommendation] = [.hold, .reduce, .deload]
}

enum VariationLoadingMode: Codable, Hashable {
    case primaryLiftTargetMultiplier(Double)
    case externalLoadOnly
    case basePlusChains(baseMultiplier: Double, chainUnitPerSide: Double)
}

struct VariationProfile: Identifiable, Codable, Hashable {
    let name: String
    let lift: LiftType
    let loadingMode: VariationLoadingMode
    let defaultRelativeLoad: Double
    let helperText: String?

    var id: String { name }
}

struct VariationSelection: Codable, Hashable {
    var profileName: String
    var chainCountPerSide: Int

    init(profileName: String, chainCountPerSide: Int = 0) {
        self.profileName = profileName
        self.chainCountPerSide = chainCountPerSide
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let profileName = try? singleValue.decode(String.self) {
            self.profileName = profileName
            self.chainCountPerSide = 0
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileName = try container.decode(String.self, forKey: .profileName)
        chainCountPerSide = try container.decodeIfPresent(Int.self, forKey: .chainCountPerSide) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profileName, forKey: .profileName)
        try container.encode(chainCountPerSide, forKey: .chainCountPerSide)
    }

    private enum CodingKeys: String, CodingKey {
        case profileName
        case chainCountPerSide
    }
}

struct ProgramEntry: Identifiable, Codable, Hashable {
    let week: Int
    let day: TrainingDay
    let primaryLift: LiftType
    let plannedType: PlannedSetType
    let sets: Int
    let reps: Int
    let phase: TrainingPhase

    var id: String { "\(week)-\(day.rawValue)-\(primaryLift.rawValue)" }
    var key: String { "\(week)-\(day.rawValue)" }

    var planLabel: String {
        plannedType == .workingSets ? "\(sets)x\(reps)" : plannedType.rawValue
    }
}

struct WorkoutSet: Identifiable, Codable, Hashable {
    let id: UUID
    var setOrder: Int
    var setType: WorkoutSetType
    var exerciseName: String
    var weight: Double?
    var reps: Int?
    var rpe: Double?
    var completed: Bool
    var skipped: Bool
    var variationProfileName: String?
    var chainCountPerSide: Int
    var chainUnitWeightPerSide: Double?

    init(
        id: UUID = UUID(),
        setOrder: Int,
        setType: WorkoutSetType,
        exerciseName: String,
        weight: Double?,
        reps: Int?,
        rpe: Double? = nil,
        completed: Bool = false,
        skipped: Bool = false,
        variationProfileName: String? = nil,
        chainCountPerSide: Int = 0,
        chainUnitWeightPerSide: Double? = nil
    ) {
        self.id = id
        self.setOrder = setOrder
        self.setType = setType
        self.exerciseName = exerciseName
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.completed = completed
        self.skipped = skipped
        self.variationProfileName = variationProfileName
        self.chainCountPerSide = chainCountPerSide
        self.chainUnitWeightPerSide = chainUnitWeightPerSide
    }

    var totalChainLoad: Double {
        guard let chainUnitWeightPerSide else { return 0 }
        return Double(chainCountPerSide) * chainUnitWeightPerSide * 2
    }

    var totalDisplayedLoad: Double {
        (weight ?? 0) + totalChainLoad
    }

    var volumeContribution: Double {
        guard completed, !skipped, let reps else { return 0 }
        return totalDisplayedLoad * Double(reps)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        setOrder = try container.decode(Int.self, forKey: .setOrder)
        setType = try container.decode(WorkoutSetType.self, forKey: .setType)
        exerciseName = try container.decode(String.self, forKey: .exerciseName)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        completed = try container.decode(Bool.self, forKey: .completed)
        skipped = try container.decode(Bool.self, forKey: .skipped)
        variationProfileName = try container.decodeIfPresent(String.self, forKey: .variationProfileName)
        chainCountPerSide = try container.decodeIfPresent(Int.self, forKey: .chainCountPerSide) ?? 0
        chainUnitWeightPerSide = try container.decodeIfPresent(Double.self, forKey: .chainUnitWeightPerSide)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(setOrder, forKey: .setOrder)
        try container.encode(setType, forKey: .setType)
        try container.encode(exerciseName, forKey: .exerciseName)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(reps, forKey: .reps)
        try container.encodeIfPresent(rpe, forKey: .rpe)
        try container.encode(completed, forKey: .completed)
        try container.encode(skipped, forKey: .skipped)
        try container.encodeIfPresent(variationProfileName, forKey: .variationProfileName)
        try container.encode(chainCountPerSide, forKey: .chainCountPerSide)
        try container.encodeIfPresent(chainUnitWeightPerSide, forKey: .chainUnitWeightPerSide)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case setOrder
        case setType
        case exerciseName
        case weight
        case reps
        case rpe
        case completed
        case skipped
        case variationProfileName
        case chainCountPerSide
        case chainUnitWeightPerSide
    }
}

struct LiftState: Codable, Hashable {
    var trainingMax: Double
    var estimatedOneRepMax: Double
    var lastGoodWorkingWeight: Double?
    var fatigueScore: Double
    var lastSuccessfulSessionDate: Date?
    var lastRecommendation: EngineRecommendation
    var lastTargetAdjustmentPercent: Double
    var pendingTargetAdjustmentPercent: Double

    static let defaults: [LiftType: LiftState] = [
        .squat: LiftState(trainingMax: 300, estimatedOneRepMax: 315, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0, pendingTargetAdjustmentPercent: 0),
        .bench: LiftState(trainingMax: 215, estimatedOneRepMax: 225, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0, pendingTargetAdjustmentPercent: 0),
        .deadlift: LiftState(trainingMax: 385, estimatedOneRepMax: 405, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0, pendingTargetAdjustmentPercent: 0),
        .shoulderPress: LiftState(trainingMax: 125, estimatedOneRepMax: 135, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0, pendingTargetAdjustmentPercent: 0),
        .barbellRow: LiftState(trainingMax: 185, estimatedOneRepMax: 195, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0, pendingTargetAdjustmentPercent: 0)
    ]

    init(
        trainingMax: Double,
        estimatedOneRepMax: Double,
        lastGoodWorkingWeight: Double?,
        fatigueScore: Double,
        lastSuccessfulSessionDate: Date?,
        lastRecommendation: EngineRecommendation,
        lastTargetAdjustmentPercent: Double,
        pendingTargetAdjustmentPercent: Double
    ) {
        self.trainingMax = trainingMax
        self.estimatedOneRepMax = estimatedOneRepMax
        self.lastGoodWorkingWeight = lastGoodWorkingWeight
        self.fatigueScore = fatigueScore
        self.lastSuccessfulSessionDate = lastSuccessfulSessionDate
        self.lastRecommendation = lastRecommendation
        self.lastTargetAdjustmentPercent = lastTargetAdjustmentPercent
        self.pendingTargetAdjustmentPercent = pendingTargetAdjustmentPercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trainingMax = try container.decode(Double.self, forKey: .trainingMax)
        estimatedOneRepMax = try container.decode(Double.self, forKey: .estimatedOneRepMax)
        lastGoodWorkingWeight = try container.decodeIfPresent(Double.self, forKey: .lastGoodWorkingWeight)
        fatigueScore = try container.decode(Double.self, forKey: .fatigueScore)
        lastSuccessfulSessionDate = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulSessionDate)
        lastRecommendation = try container.decode(EngineRecommendation.self, forKey: .lastRecommendation)
        lastTargetAdjustmentPercent = try container.decodeIfPresent(Double.self, forKey: .lastTargetAdjustmentPercent) ?? 0
        pendingTargetAdjustmentPercent = try container.decodeIfPresent(Double.self, forKey: .pendingTargetAdjustmentPercent) ?? lastTargetAdjustmentPercent
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trainingMax, forKey: .trainingMax)
        try container.encode(estimatedOneRepMax, forKey: .estimatedOneRepMax)
        try container.encodeIfPresent(lastGoodWorkingWeight, forKey: .lastGoodWorkingWeight)
        try container.encode(fatigueScore, forKey: .fatigueScore)
        try container.encodeIfPresent(lastSuccessfulSessionDate, forKey: .lastSuccessfulSessionDate)
        try container.encode(lastRecommendation, forKey: .lastRecommendation)
        try container.encode(lastTargetAdjustmentPercent, forKey: .lastTargetAdjustmentPercent)
        try container.encode(pendingTargetAdjustmentPercent, forKey: .pendingTargetAdjustmentPercent)
    }

    private enum CodingKeys: String, CodingKey {
        case trainingMax
        case estimatedOneRepMax
        case lastGoodWorkingWeight
        case fatigueScore
        case lastSuccessfulSessionDate
        case lastRecommendation
        case lastTargetAdjustmentPercent
        case pendingTargetAdjustmentPercent
    }
}

struct SessionDraft: Identifiable, Codable, Hashable {
    let id: UUID
    let programEntry: ProgramEntry
    var selectedVariation: VariationSelection
    var appliedTargetAdjustmentPercent: Double
    var sets: [WorkoutSet]
    var generatedAt: Date

    init(id: UUID = UUID(), programEntry: ProgramEntry, selectedVariation: VariationSelection, appliedTargetAdjustmentPercent: Double = 0, sets: [WorkoutSet], generatedAt: Date = .now) {
        self.id = id
        self.programEntry = programEntry
        self.selectedVariation = selectedVariation
        self.appliedTargetAdjustmentPercent = appliedTargetAdjustmentPercent
        self.sets = sets
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        programEntry = try container.decode(ProgramEntry.self, forKey: .programEntry)
        if let selection = try? container.decode(VariationSelection.self, forKey: .selectedVariation) {
            selectedVariation = selection
        } else {
            let legacyVariation = try container.decode(String.self, forKey: .selectedVariation)
            selectedVariation = VariationSelection(profileName: legacyVariation)
        }
        appliedTargetAdjustmentPercent = try container.decodeIfPresent(Double.self, forKey: .appliedTargetAdjustmentPercent) ?? 0
        sets = try container.decode([WorkoutSet].self, forKey: .sets)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(programEntry, forKey: .programEntry)
        try container.encode(selectedVariation, forKey: .selectedVariation)
        try container.encode(appliedTargetAdjustmentPercent, forKey: .appliedTargetAdjustmentPercent)
        try container.encode(sets, forKey: .sets)
        try container.encode(generatedAt, forKey: .generatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case programEntry
        case selectedVariation
        case appliedTargetAdjustmentPercent
        case sets
        case generatedAt
    }
}

struct FatigueAssessment: Codable, Hashable {
    var expectedRampEffort: Double
    var expectedTopSetEffort: Double
    var actualRampEffort: Double
    var actualTopSetEffort: Double
    var expectedEffort: Double
    var actualEffort: Double
    var effortDelta: Double
    var rampFatigue: Double
    var topSetFatigue: Double
    var skipBackoffWork: Bool
    var targetAdjustmentPercent: Double
    var backoffDecisionReason: String
    var recommendation: EngineRecommendation
}

struct SessionSummary: Codable, Hashable {
    var totalVolume: Double
    var bestEstimatedOneRepMax: Double?
    var completedSetCount: Int
    var variationUsed: String?
}

struct CompletedSession: Identifiable, Codable, Hashable {
    let id: UUID
    let programEntry: ProgramEntry
    let performedOn: Date
    let variation: String
    let sets: [WorkoutSet]
    let fatigue: FatigueAssessment
    let summary: SessionSummary
    let nextTargetWeight: Double?
}

struct ProgramRun: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var programStartDate: Date
    var completedSessions: [CompletedSession]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        programStartDate: Date,
        completedSessions: [CompletedSession] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.programStartDate = programStartDate
        self.completedSessions = completedSessions
    }

    var hasActivity: Bool {
        !completedSessions.isEmpty
    }
}

struct AnalyticsPoint: Identifiable, Hashable {
    let id = UUID()
    let order: Int
    let label: String
    let value: Double?
}

struct LiftTrendSeries: Identifiable, Hashable {
    let id = UUID()
    let lift: LiftType
    let points: [AnalyticsPoint]
}

struct LiftAnalyticsSnapshot: Identifiable, Hashable {
    let id = UUID()
    let lift: LiftType
    let tonnage: Double
    let bestEstimatedOneRepMax: Double
    let variationCount: Int
    let averageFatigueDelta: Double
    let latestRecommendation: EngineRecommendation
}

struct RecommendationCount: Identifiable, Hashable {
    let id = UUID()
    let recommendation: EngineRecommendation
    let count: Int
}

struct RunLiftCallout: Identifiable, Hashable {
    let id = UUID()
    let lift: LiftType
    let completedSessions: Int
    let bestEstimatedOneRepMax: Double
    let bestWorkingWeight: Double
}

struct ProgramRunSummary: Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let completedWorkoutCount: Int
    let adherenceRate: Double
    let totalTonnage: Double
    let averageFatigueDelta: Double
    let recommendationCounts: [RecommendationCount]
    let liftCallouts: [RunLiftCallout]
}

struct ArchiveOverview: Hashable {
    let archivedProgramCount: Int
    let totalArchivedWorkouts: Int
    let totalArchivedTonnage: Double
    let bestArchivedEstimatedOneRepMax: Double
    let bestEstimatedOneRepMaxByLift: [ArchivedLiftBest]
}

struct ArchivedLiftBest: Identifiable, Hashable {
    let id = UUID()
    let lift: LiftType
    let bestEstimatedOneRepMax: Double
}

struct AppSnapshot: Codable {
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
}

struct AppSettingsSnapshot: Codable {
    var programStartDate: Date
    var selectedWeek: Int
    var selectedDay: TrainingDay
    var lastAutoSelectedDate: Date?
    var lastUsedRestDurationSeconds: Int
    var autoStartRestTimerOnCompletion: Bool
}

struct TrainingDataSnapshot: Codable {
    var drafts: [String: SessionDraft]
    var activeRun: ProgramRun
    var archivedRuns: [ProgramRun]
    var liftStates: [LiftType: LiftState]
}

struct LegacyAppSnapshot: Codable {
    var programStartDate: Date
    var selectedWeek: Int
    var selectedDay: TrainingDay
    var lastAutoSelectedDate: Date?
    var drafts: [String: SessionDraft]
    var completedSessions: [CompletedSession]
    var liftStates: [LiftType: LiftState]
}

struct LegacyAppSettingsSnapshot: Codable {
    var programStartDate: Date
    var selectedWeek: Int
    var selectedDay: TrainingDay
    var lastAutoSelectedDate: Date?
}

struct LegacyTrainingDataSnapshot: Codable {
    var drafts: [String: SessionDraft]
    var completedSessions: [CompletedSession]
    var liftStates: [LiftType: LiftState]
}

extension Array where Element == WorkoutSet {
    func sortedForDisplay() -> [WorkoutSet] {
        sorted { lhs, rhs in
            if lhs.setType == rhs.setType {
                let lhsWeight = lhs.displaySortWeight
                let rhsWeight = rhs.displaySortWeight

                if lhsWeight != rhsWeight {
                    return lhsWeight < rhsWeight
                }

                if lhs.exerciseName != rhs.exerciseName {
                    return lhs.exerciseName < rhs.exerciseName
                }

                return lhs.setOrder < rhs.setOrder
            }
            return lhs.setType.sortIndex < rhs.setType.sortIndex
        }
    }
}

private extension WorkoutSet {
    var displaySortWeight: Double {
        let load = totalDisplayedLoad
        if load > 0 {
            return load
        }

        if let weight, weight > 0 {
            return weight
        }

        return .greatestFiniteMagnitude
    }
}
