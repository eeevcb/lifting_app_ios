# LiftingApp iOS Spec

## Product shape

The app is a program-driven lifting log for powerlifting-style training.

Core user flows:

- open today's workout
- edit and complete sets
- finish workout, lock the session, and review or reopen it later
- review dashboard analytics
- browse the active program
- archive finished programs and review historical runs

## Main components

### Workout

- session header with current lift, week/day, and training max
- rest timer with saved default duration, auto-start preference, and modal countdown
- program start / week / day selection
- auto-target card with estimated 1RM, target, fatigue, progression, and training max
- engine insights card with expected vs actual effort and next-target logic
- variation selector
- workout log rows for each set
- finish-workout action, locked finished state, review summary, and reopen flow

### Dashboard

- estimated 1RM trend
- weekly volume
- fatigue flags
- target shifts
- progression mix
- by-lift snapshots
- recent engine calls
- variation usage

All week-based charts are rendered in ascending week order across the full 12-week span, not completion order.

### Program

- active-run summary
- current 12-week program schedule
- Week 11 Friday is a back-only `Barbell Row` day instead of a deadlift day
- completion state attached to the active program run
- start-new-program flow with archive-and-restart behavior

### Archive

- archived program list
- per-run summary metrics
- per-run charts
- session history for finished programs
- delete action for individual archived runs

## Data model

### Lift state

Each primary lift keeps:

- training max
- estimated 1RM
- last good working weight
- fatigue score
- last successful session date
- last recommendation
- last target adjustment percent

Tracked lifts include squat, bench, shoulder press, deadlift, and barbell row.

### Program run

One active run exists at a time.

Each run stores:

- start date
- optional end date
- program start date
- completed sessions

Archived runs are read-only except for deletion.

### Session draft

Each draft stores:

- program entry
- selected variation
- generated sets
- generation timestamp

Draft regeneration rules:

- completed rows are preserved
- skipped rows are preserved
- unfinished generated rows can be refreshed when lift state changes

### Variation system

Each variation profile stores:

- lift association
- display name
- loading mode
- default relative load
- optional helper copy

Supported loading modes:

- primary-lift target multiplier
- external-load-only
- straight-bar base plus chains

## Current default variation loads

### Squat

- Box Squat: `85%`
- Safety Bar Squat: `90%`

### Bench

- Bench Press with Chains: `80%` straight-bar load plus chain increments
- Bench Press with Blocks: `95%`
- Incline Bench: `80%`
- Close Grip Bench: `90%`

### Deadlift

- Deadlift vs Bands: `60%` straight-bar load
- Deadlift from Blocks: `105%`
- Deficit Deadlift: `90%`
- Romanian Deadlift: `80%`
- Barbell Row: `55%`

### Press / accessory

- Landmine Press: `75%`
- Pull Ups: `0` external load
- Barbell Curl: `35%`
- Skull Crushers: `40%`
- Shrugs: `125%`

## Chain handling

Bench with chains stores:

- straight-bar load
- chain count per side
- chain unit weight per side

Default rule:

- `1` chain increment means one chain on each side
- default chain unit is `15 lb` per side
- `1` increment therefore equals `30 lb` total chain load

The UI should show straight-bar load, added chain load, and total top-end load separately.

## Deload rules

Deload days use lower load with more total working sets than the old `0x0` placeholder.

- squat, bench, shoulder press: `5 x 5 @ 60%`
- deadlift: `4 x 5 @ 60%`

Deload days should:

- use simpler warmups
- avoid default backoff rows
- keep effort expectations low

## Engine behavior

The progression engine:

1. computes expected ramp effort and expected working-set effort
2. reads only completed, non-skipped sets with RPE
3. computes actual ramp and working-set effort separately
4. derives ramp fatigue, working-set fatigue, and overall effort delta
5. decides `Progression`, `Reduce`, or `Deload`
6. may skip backoff work if recorded fatigue is high enough
7. updates training max, estimated 1RM, fatigue score, and future targets

Safety rules:

- skipped sets alone do not trigger deload
- no RPE data means neutral progression
- completed effort data is the only fatigue evidence path

Finished-workout rules:

- a finished session is locked until reopened
- reopening removes that session result from the active run
- lift state is rebuilt by replaying the remaining completed sessions in program order

## Persistence

The app persists:

- settings
- active run
- archived runs
- lift states
- drafts
- saved default rest duration
- auto-start rest-timer preference

Persistence is file-backed JSON with migration support from earlier snapshot formats.

## Input and timer UX

- Numeric workout fields should support tap-outside dismissal and a keyboard `Done` action
- The workout screen is the place where the user sets the default rest duration
- Preset buttons update the saved default
- Custom timer entry updates the saved default after confirmation
- Marking a set completed can auto-start the timer when the user preference is enabled
- The active timer is presented modally and can be canceled without changing the saved default
- Skipped rows are locked and visually dimmed until unskipped
