# LiftingApp iOS Scaffold

This folder contains a native SwiftUI translation of the React wireframe.

## What is included

- Program-driven workout generation for squat, bench, deadlift, and shoulder press
- A draft session workflow with warmup, ramp, top, backoff, and variation sets
- A `finishWorkout` flow that runs a first-pass fatigue engine and updates lift state
- Real analytics computed from completed session history
- A 3-tab SwiftUI shell for Workout, Dashboard, and Program

## Current architecture

- `Models.swift`: domain models, lift state, analytics, and fatigue decisions
- `ProgramDefinition.swift`: seeded 12-week program and variation choices
- `WorkoutEngine.swift`: session generation and fatigue/training-max updates
- `PersistenceController.swift`: prototype persistence using `UserDefaults`
- `AppModel.swift`: app state, session orchestration, and analytics aggregation
- `Views/`: SwiftUI screens

## Generate an Xcode project

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) on a Mac with Xcode.
2. From `LiftingAppiOS`, run `xcodegen generate`.
3. Open the generated `LiftingApp.xcodeproj`.

## Notes

- This scaffold targets iOS 17 and uses Observation plus Swift Charts.
- Persistence is intentionally lightweight for the prototype. The next storage step can swap `PersistenceController` to SwiftData or another app storage layer without rewriting the view layer.
