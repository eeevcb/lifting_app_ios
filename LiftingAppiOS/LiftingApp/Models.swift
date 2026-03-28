import Foundation

enum AppTab: Hashable {
    case workout
    case dashboard
    case program
}

enum LiftType: String, CaseIterable, Codable, Hashable, Identifiable {
    case squat
    case bench
    case shoulderPress
    case deadlift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squat: "Squat"
        case .bench: "Bench"
        case .shoulderPress: "Shoulder Press"
        case .deadlift: "Deadlift"
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
        case .topSet: "Top Set"
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
}

extension EngineRecommendation {
    static let allCasesForDashboard: [EngineRecommendation] = [.hold, .reduce, .deload]
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

    init(
        id: UUID = UUID(),
        setOrder: Int,
        setType: WorkoutSetType,
        exerciseName: String,
        weight: Double?,
        reps: Int?,
        rpe: Double? = nil,
        completed: Bool = false,
        skipped: Bool = false
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
    }

    var volumeContribution: Double {
        guard completed, !skipped, let weight, let reps else { return 0 }
        return weight * Double(reps)
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

    static let defaults: [LiftType: LiftState] = [
        .squat: LiftState(trainingMax: 300, estimatedOneRepMax: 315, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0),
        .bench: LiftState(trainingMax: 215, estimatedOneRepMax: 225, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0),
        .deadlift: LiftState(trainingMax: 385, estimatedOneRepMax: 405, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0),
        .shoulderPress: LiftState(trainingMax: 125, estimatedOneRepMax: 135, lastGoodWorkingWeight: nil, fatigueScore: 0, lastSuccessfulSessionDate: nil, lastRecommendation: .hold, lastTargetAdjustmentPercent: 0)
    ]
}

struct SessionDraft: Identifiable, Codable, Hashable {
    let id: UUID
    let programEntry: ProgramEntry
    var selectedVariation: String
    var sets: [WorkoutSet]
    var generatedAt: Date

    init(id: UUID = UUID(), programEntry: ProgramEntry, selectedVariation: String, sets: [WorkoutSet], generatedAt: Date = .now) {
        self.id = id
        self.programEntry = programEntry
        self.selectedVariation = selectedVariation
        self.sets = sets
        self.generatedAt = generatedAt
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

struct AnalyticsPoint: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Double
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

struct AppSnapshot: Codable {
    var programStartDate: Date
    var selectedWeek: Int
    var selectedDay: TrainingDay
    var drafts: [String: SessionDraft]
    var completedSessions: [CompletedSession]
    var liftStates: [LiftType: LiftState]
}

extension Array where Element == WorkoutSet {
    func sortedForDisplay() -> [WorkoutSet] {
        sorted { lhs, rhs in
            if lhs.setType == rhs.setType {
                return lhs.setOrder < rhs.setOrder
            }
            return lhs.setType.sortIndex < rhs.setType.sortIndex
        }
    }
}
