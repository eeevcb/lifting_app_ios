# LiftingApp iOS

This folder contains the native SwiftUI version of the lifting app.

## What the app does

- Generates workout drafts from a 12-week program for squat, bench, shoulder press, deadlift, and barbell row
- Builds each session from warmup, ramp, working, backoff, and variation sets
- Runs a fatigue/progression engine when a workout is finished
- Updates lift state, training max, and future workout targets from completed sessions
- Stores active program history plus archived program runs
- Shows real dashboard analytics based on completed sessions
- Uses a saved-default rest timer that can auto-start when sets are marked complete

## Engine logic

The current engine is intentionally RPE-driven.

1. Each workout has an expected ramp effort and expected working-set effort based on the phase and plan type.
2. When the user finishes a workout, the engine only looks at completed, non-skipped sets with recorded RPE.
3. It averages ramp-set RPE and working-set RPE separately.
4. It computes:
   - ramp fatigue = actual ramp effort minus expected ramp effort
   - working-set fatigue = actual working-set effort minus expected working-set effort
   - overall delta = weighted actual effort minus weighted expected effort
5. It then chooses a progression call:
   - `Progression` when fatigue stays in range
   - `Reduce` when fatigue is moderately high
   - `Deload` when fatigue is clearly above target
6. Skipped sets by themselves do not trigger deload logic.
7. Missing RPE data keeps the engine neutral instead of auto-deloading.
8. Backoff work is only auto-skipped when actual recorded effort is high enough to justify it.

## Variation loading

Variation lifts are seeded from the day's working-set target.

- Most variations use a default relative load multiplier
- Deadlift days now include `Barbell Row` as a variation option
- Pull-ups default to `0` external load
- Bench with chains tracks straight-bar weight and chain load separately
- Chain count is per side, using `15 lb` per side by default
- Users still edit the actual variation weight directly in the workout log

## Program updates

- Week 11 Friday is now a back-only day with `Barbell Row` as the main lift
- Finished workouts are locked until the user explicitly reopens them
- Finished workouts can be reviewed from the summary sheet without re-running the same day
- Reopening a workout restores the previously finished set values so users can correct data-entry mistakes

## Dashboard behavior

- Week-based charts always render left-to-right across the full 12-week program
- Missing weeks remain visible as gaps instead of collapsing the axis
- Fatigue and target-shift charts include visible y-axis labels

## Deload generation

Deload days now generate real working sets instead of `0x0`.

- Squat, bench, shoulder press: `5 x 5 @ 60%`
- Deadlift: `4 x 5 @ 60%`
- Warmups stay lighter and simpler
- Default backoff rows are not added on deload days

## Workout input behavior

- Numeric workout fields use iPhone-friendly keyboard dismissal with tap-outside and a keyboard `Done` action
- Completed set rows lock their values until the user explicitly unchecks completion
- Updating estimated 1RM preserves completed and skipped rows in the current draft
- Only unfinished generated rows are recalculated when 1RM changes
- The workout screen uses button-based day selection and a paged week selector instead of dropdowns
- Program start date is edited only from the Program tab, not from the Workout screen

## Rest timer behavior

- The workout screen stores a saved default rest duration instead of treating presets as one-off timers
- Quick picks `2`, `3`, and `5` minutes update the saved default immediately
- Custom minutes update the saved default after confirmation
- Auto-start-on-completion is persisted and defaults to `on`
- When the timer starts, it appears in a modal that can be closed early without changing the saved default

## Main files

- `LiftingApp/Models.swift`: core models, variation metadata, lift state, archive summaries
- `LiftingApp/ProgramDefinition.swift`: seeded 12-week program and variation profiles
- `LiftingApp/WorkoutEngine.swift`: session generation, variation defaults, and fatigue logic
- `LiftingApp/AppModel.swift`: app orchestration, persistence coordination, and analytics aggregation
- `LiftingApp/PersistenceController.swift`: local snapshot persistence and migration
- `LiftingApp/Views/`: SwiftUI screens

## Generate an Xcode project

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) on a Mac with Xcode.
2. From `LiftingAppiOS`, run `xcodegen generate`.
3. Open the generated `LiftingApp.xcodeproj`.

## Additional docs

See [`APP_SPEC.md`](./APP_SPEC.md) for a product-level component and behavior spec.
