import Foundation

enum ProgramDefinition {
    static let defaultStartDate: Date = {
        DateComponents(calendar: .current, year: 2026, month: 3, day: 30).date ?? .now
    }()

    static let programDays: [ProgramEntry] = [
        ProgramEntry(week: 1, day: .monday, primaryLift: .squat, plannedType: .workingSets, sets: 4, reps: 8, phase: .volume),
        ProgramEntry(week: 1, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 4, reps: 8, phase: .volume),
        ProgramEntry(week: 1, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 4, reps: 8, phase: .volume),
        ProgramEntry(week: 1, day: .friday, primaryLift: .deadlift, plannedType: .workingSets, sets: 4, reps: 8, phase: .volume),
        ProgramEntry(week: 2, day: .monday, primaryLift: .squat, plannedType: .workingSets, sets: 5, reps: 5, phase: .volume),
        ProgramEntry(week: 2, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 5, reps: 5, phase: .volume),
        ProgramEntry(week: 2, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 5, reps: 5, phase: .volume),
        ProgramEntry(week: 2, day: .friday, primaryLift: .deadlift, plannedType: .workingSets, sets: 5, reps: 5, phase: .volume),
        ProgramEntry(week: 3, day: .monday, primaryLift: .squat, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 3, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 3, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 3, day: .friday, primaryLift: .deadlift, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 4, day: .monday, primaryLift: .squat, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 4, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 4, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 4, day: .friday, primaryLift: .deadlift, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 5, day: .monday, primaryLift: .squat, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 5, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 5, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 5, day: .friday, primaryLift: .deadlift, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 6, day: .monday, primaryLift: .squat, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 6, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 6, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 6, day: .friday, primaryLift: .deadlift, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 7, day: .monday, primaryLift: .squat, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 7, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 7, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 7, day: .friday, primaryLift: .deadlift, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 8, day: .monday, primaryLift: .squat, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 8, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 8, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 8, day: .friday, primaryLift: .deadlift, plannedType: .maxSingle, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 9, day: .monday, primaryLift: .squat, plannedType: .maxSingle, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 9, day: .wednesday, primaryLift: .bench, plannedType: .maxSingle, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 9, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 9, day: .friday, primaryLift: .deadlift, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 10, day: .monday, primaryLift: .squat, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 10, day: .wednesday, primaryLift: .bench, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 10, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 10, day: .friday, primaryLift: .deadlift, plannedType: .opener, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 11, day: .monday, primaryLift: .squat, plannedType: .opener, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 11, day: .wednesday, primaryLift: .bench, plannedType: .opener, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 11, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .taper),
        ProgramEntry(week: 11, day: .friday, primaryLift: .deadlift, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 12, day: .monday, primaryLift: .squat, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 12, day: .wednesday, primaryLift: .bench, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 12, day: .thursday, primaryLift: .shoulderPress, plannedType: .deload, sets: 0, reps: 0, phase: .taper),
        ProgramEntry(week: 12, day: .friday, primaryLift: .deadlift, plannedType: .deload, sets: 0, reps: 0, phase: .taper)
    ]

    static let variationOptions: [LiftType: [String]] = [
        .squat: ["Box Squat", "Safety Bar Squat"],
        .bench: ["Bench Press with Chains", "Bench Press with Blocks", "Incline Bench", "Close Grip Bench"],
        .deadlift: ["Deadlift vs Bands", "Deadlift from Blocks", "Deficit Deadlift", "Romanian Deadlift"],
        .shoulderPress: ["Landmine Press", "Pull Ups", "Barbell Curl", "Skull Crushers", "Shrugs"]
    ]

    static func entry(week: Int, day: TrainingDay) -> ProgramEntry? {
        programDays.first { $0.week == week && $0.day == day }
    }

    static func weeks() -> [Int] {
        Array(Set(programDays.map(\.week))).sorted()
    }
}
