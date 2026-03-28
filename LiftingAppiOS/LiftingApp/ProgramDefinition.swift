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
        ProgramEntry(week: 7, day: .friday, primaryLift: .deadlift, plannedType: .deload, sets: 4, reps: 5, phase: .taper),
        ProgramEntry(week: 8, day: .monday, primaryLift: .squat, plannedType: .deload, sets: 5, reps: 5, phase: .taper),
        ProgramEntry(week: 8, day: .wednesday, primaryLift: .bench, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 8, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .strength),
        ProgramEntry(week: 8, day: .friday, primaryLift: .deadlift, plannedType: .maxSingle, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 9, day: .monday, primaryLift: .squat, plannedType: .maxSingle, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 9, day: .wednesday, primaryLift: .bench, plannedType: .maxSingle, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 9, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 9, day: .friday, primaryLift: .deadlift, plannedType: .deload, sets: 4, reps: 5, phase: .taper),
        ProgramEntry(week: 10, day: .monday, primaryLift: .squat, plannedType: .deload, sets: 5, reps: 5, phase: .taper),
        ProgramEntry(week: 10, day: .wednesday, primaryLift: .bench, plannedType: .deload, sets: 5, reps: 5, phase: .taper),
        ProgramEntry(week: 10, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 2, reps: 2, phase: .peak),
        ProgramEntry(week: 10, day: .friday, primaryLift: .deadlift, plannedType: .opener, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 11, day: .monday, primaryLift: .squat, plannedType: .opener, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 11, day: .wednesday, primaryLift: .bench, plannedType: .opener, sets: 1, reps: 1, phase: .peak),
        ProgramEntry(week: 11, day: .thursday, primaryLift: .shoulderPress, plannedType: .workingSets, sets: 3, reps: 3, phase: .taper),
        ProgramEntry(week: 11, day: .friday, primaryLift: .barbellRow, plannedType: .workingSets, sets: 4, reps: 8, phase: .taper),
        ProgramEntry(week: 12, day: .monday, primaryLift: .squat, plannedType: .deload, sets: 5, reps: 5, phase: .taper),
        ProgramEntry(week: 12, day: .wednesday, primaryLift: .bench, plannedType: .deload, sets: 5, reps: 5, phase: .taper),
        ProgramEntry(week: 12, day: .thursday, primaryLift: .shoulderPress, plannedType: .deload, sets: 5, reps: 5, phase: .taper),
        ProgramEntry(week: 12, day: .friday, primaryLift: .deadlift, plannedType: .deload, sets: 4, reps: 5, phase: .taper)
    ]

    static let variationProfiles: [LiftType: [VariationProfile]] = [
        .squat: [
            VariationProfile(name: "Box Squat", lift: .squat, loadingMode: .primaryLiftTargetMultiplier(0.85), defaultRelativeLoad: 0.85, helperText: "Defaults to 85% of the day’s squat working target."),
            VariationProfile(name: "Safety Bar Squat", lift: .squat, loadingMode: .primaryLiftTargetMultiplier(0.90), defaultRelativeLoad: 0.90, helperText: "Defaults to 90% of the day’s squat working target.")
        ],
        .bench: [
            VariationProfile(name: "Bench Press with Chains", lift: .bench, loadingMode: .basePlusChains(baseMultiplier: 0.80, chainUnitPerSide: 15), defaultRelativeLoad: 0.80, helperText: "Chain count is per side. 1 means one 15 lb chain on each side, for 30 lb total added chain weight."),
            VariationProfile(name: "Bench Press with Blocks", lift: .bench, loadingMode: .primaryLiftTargetMultiplier(0.95), defaultRelativeLoad: 0.95, helperText: "Defaults to 95% of the day’s bench working target."),
            VariationProfile(name: "Incline Bench", lift: .bench, loadingMode: .primaryLiftTargetMultiplier(0.80), defaultRelativeLoad: 0.80, helperText: "Defaults to 80% of the day’s bench working target."),
            VariationProfile(name: "Close Grip Bench", lift: .bench, loadingMode: .primaryLiftTargetMultiplier(0.90), defaultRelativeLoad: 0.90, helperText: "Defaults to 90% of the day’s bench working target.")
        ],
        .deadlift: [
            VariationProfile(name: "Deadlift vs Bands", lift: .deadlift, loadingMode: .primaryLiftTargetMultiplier(0.60), defaultRelativeLoad: 0.60, helperText: "Defaults to 60% straight-bar load for the day’s deadlift target."),
            VariationProfile(name: "Deadlift from Blocks", lift: .deadlift, loadingMode: .primaryLiftTargetMultiplier(1.05), defaultRelativeLoad: 1.05, helperText: "Defaults to 105% of the day’s deadlift working target."),
            VariationProfile(name: "Deficit Deadlift", lift: .deadlift, loadingMode: .primaryLiftTargetMultiplier(0.90), defaultRelativeLoad: 0.90, helperText: "Defaults to 90% of the day’s deadlift working target."),
            VariationProfile(name: "Romanian Deadlift", lift: .deadlift, loadingMode: .primaryLiftTargetMultiplier(0.80), defaultRelativeLoad: 0.80, helperText: "Defaults to 80% of the day’s deadlift working target.")
            , VariationProfile(name: "Barbell Row", lift: .deadlift, loadingMode: .primaryLiftTargetMultiplier(0.55), defaultRelativeLoad: 0.55, helperText: "Defaults to 55% of the day's deadlift working target for back-only rowing work.")
        ],
        .shoulderPress: [
            VariationProfile(name: "Landmine Press", lift: .shoulderPress, loadingMode: .primaryLiftTargetMultiplier(0.75), defaultRelativeLoad: 0.75, helperText: "Defaults to 75% of the day’s press working target."),
            VariationProfile(name: "Pull Ups", lift: .shoulderPress, loadingMode: .externalLoadOnly, defaultRelativeLoad: 0, helperText: "Defaults to 0 added load. Add weight only if using a belt."),
            VariationProfile(name: "Barbell Curl", lift: .shoulderPress, loadingMode: .primaryLiftTargetMultiplier(0.35), defaultRelativeLoad: 0.35, helperText: "Defaults to 35% of the day’s press working target."),
            VariationProfile(name: "Skull Crushers", lift: .shoulderPress, loadingMode: .primaryLiftTargetMultiplier(0.40), defaultRelativeLoad: 0.40, helperText: "Defaults to 40% of the day’s press working target."),
            VariationProfile(name: "Shrugs", lift: .shoulderPress, loadingMode: .primaryLiftTargetMultiplier(1.25), defaultRelativeLoad: 1.25, helperText: "Defaults to 125% of the day’s press working target.")
        ]
    ]

    static func entry(week: Int, day: TrainingDay) -> ProgramEntry? {
        programDays.first { $0.week == week && $0.day == day }
    }

    static func weeks() -> [Int] {
        Array(Set(programDays.map(\.week))).sorted()
    }

    static func variationProfiles(for lift: LiftType) -> [VariationProfile] {
        variationProfiles[lift] ?? []
    }

    static func variationNames(for lift: LiftType) -> [String] {
        variationProfiles(for: lift).map(\.name)
    }

    static func variationProfile(named name: String, for lift: LiftType) -> VariationProfile? {
        variationProfiles(for: lift).first { $0.name == name }
    }

    static func variationProfile(named name: String) -> VariationProfile? {
        variationProfiles.values.flatMap { $0 }.first { $0.name == name }
    }

    static func defaultVariationSelection(for lift: LiftType) -> VariationSelection {
        guard let profile = variationProfiles(for: lift).first else {
            return VariationSelection(profileName: "")
        }
        return defaultSelection(for: profile)
    }

    static func defaultSelection(for profile: VariationProfile) -> VariationSelection {
        switch profile.loadingMode {
        case .basePlusChains:
            return VariationSelection(profileName: profile.name, chainCountPerSide: 1)
        case .externalLoadOnly, .primaryLiftTargetMultiplier:
            return VariationSelection(profileName: profile.name, chainCountPerSide: 0)
        }
    }
}
