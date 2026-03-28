import SwiftUI

struct WorkoutScreen: View {
    @Environment(AppModel.self) private var model

    private let cardBackground = Color(uiColor: .secondarySystemBackground)
    private let insetBackground = Color(uiColor: .systemBackground)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let entry = model.currentEntry, let liftState = model.currentLiftState, let draft = model.currentDraft {
                    sessionHeader(entry: entry, liftState: liftState)
                    selectionCard
                    autoTargetsCard(entry: entry, liftState: liftState)
                    variationCard(entry: entry, draft: draft)
                    setActionsCard
                    workoutLogCard(draft: draft)
                    finishWorkoutCard(entry: entry, liftState: liftState)
                } else {
                    ContentUnavailableView("No Workout", systemImage: "calendar.badge.exclamationmark", description: Text("There is no program entry for the selected day."))
                }
            }
            .padding()
        }
        .navigationTitle("Workout")
    }

    private func sessionHeader(entry: ProgramEntry, liftState: LiftState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.primaryLift.displayName)
                .font(.largeTitle.bold())
            HStack {
                Label("Week \(entry.week) \(entry.day.rawValue)", systemImage: "calendar")
                Spacer()
                Text(entry.phase.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.12), in: Capsule())
            }
            Text("Planned: \(entry.planLabel)  |  Training Max \(Int(liftState.trainingMax)) lb")
                .foregroundStyle(.secondary)
        }
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Setup")
                .font(.headline)

            DatePicker("Program Start", selection: Binding(
                get: { model.programStartDate },
                set: { model.updateProgramStartDate($0) }
            ), displayedComponents: .date)

            Picker("Week", selection: Binding(
                get: { model.selectedWeek },
                set: { model.select(week: $0, day: model.selectedDay) }
            )) {
                ForEach(model.weeks, id: \.self) { week in
                    Text("Week \(week)").tag(week)
                }
            }

            Picker("Day", selection: Binding(
                get: { model.selectedDay },
                set: { model.select(week: model.selectedWeek, day: $0) }
            )) {
                ForEach(TrainingDay.allCases) { day in
                    Text(day.rawValue).tag(day)
                }
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func autoTargetsCard(entry: ProgramEntry, liftState: LiftState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto Targets")
                .font(.headline)

            HStack {
                metricBlock(title: "Estimated 1RM", value: "\(Int(liftState.estimatedOneRepMax)) lb")
                metricBlock(title: "Working Target", value: "\(Int(model.currentTargetWeight ?? 0)) lb")
            }

            HStack {
                metricBlock(title: "Fatigue", value: String(format: "%.1f", liftState.fatigueScore))
                metricBlock(title: "Recommendation", value: liftState.lastRecommendation.rawValue.capitalized)
            }

            HStack {
                Text("Adjust \(entry.primaryLift.displayName) 1RM")
                Spacer()
                Stepper(
                    "\(Int(liftState.estimatedOneRepMax))",
                    value: Binding(
                        get: { Int(liftState.estimatedOneRepMax) },
                        set: { model.updateEstimatedOneRepMax(for: entry.primaryLift, to: Double($0)) }
                    ),
                    in: 45...1000,
                    step: 5
                )
                .labelsHidden()
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func variationCard(entry: ProgramEntry, draft: SessionDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Variation")
                .font(.headline)

            Picker("Accessory", selection: Binding(
                get: { draft.selectedVariation },
                set: { model.updateVariation($0) }
            )) {
                ForEach(ProgramDefinition.variationOptions[entry.primaryLift] ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }

            Text("This selection is kept with the session draft and can later feed variation-impact analytics.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var setActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Sets")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                actionButton("Warmup", systemImage: "flame", action: { model.addSet(.warmup) })
                actionButton("Ramp", systemImage: "arrow.up.forward", action: { model.addSet(.ramp) })
                actionButton("Backoff", systemImage: "arrow.down", action: { model.addSet(.backoff) })
                actionButton("Variation", systemImage: "plus.square.on.square", action: { model.addSet(.variation) })
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func workoutLogCard(draft: SessionDraft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Log")
                .font(.headline)

            ForEach(draft.sets.sortedForDisplay()) { set in
                WorkoutSetRow(
                    set: set,
                    variationOptions: ProgramDefinition.variationOptions[draft.programEntry.primaryLift] ?? [],
                    onChange: { updatedSet in
                        model.updateSet(set.id) { current in
                            current = updatedSet
                        }
                    },
                    onDelete: {
                        model.removeSet(set.id)
                    }
                )
            }

            if let summary = model.currentSummary {
                HStack {
                    metricBlock(title: "Volume", value: "\(Int(summary.totalVolume)) lb")
                    metricBlock(title: "Best e1RM", value: summary.bestEstimatedOneRepMax.map { "\(Int($0)) lb" } ?? "--")
                }
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func finishWorkoutCard(entry: ProgramEntry, liftState: LiftState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish Workout")
                .font(.headline)
            Text("Completing a session runs the fatigue engine, updates \(entry.primaryLift.displayName) state, stores analytics, and seeds the next target.")
                .foregroundStyle(.secondary)
            Button("Finish Workout") {
                model.finishWorkout()
            }
            .buttonStyle(.borderedProminent)
            .tint(liftState.lastRecommendation == .deload ? .orange : .blue)
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

private struct WorkoutSetRow: View {
    let set: WorkoutSet
    let variationOptions: [String]
    let onChange: (WorkoutSet) -> Void
    let onDelete: () -> Void

    private let insetBackground = Color(uiColor: .systemBackground)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(set.setOrder). \(set.setType.displayName)")
                    .font(.headline)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }

            if set.setType == .variation {
                Picker("Exercise", selection: stringBinding(\.exerciseName)) {
                    ForEach(variationOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } else {
                Text(set.exerciseName)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("Weight", value: doubleBinding(\.weight), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)

                TextField("Reps", value: intBinding(\.reps), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)

                TextField("RPE", value: doubleBinding(\.rpe), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }

            Toggle("Completed", isOn: Binding(
                get: { set.completed },
                set: { newValue in
                    var updated = set
                    updated.completed = newValue
                    if newValue {
                        updated.skipped = false
                    }
                    onChange(updated)
                }
            ))

            Toggle("Skipped", isOn: Binding(
                get: { set.skipped },
                set: { newValue in
                    var updated = set
                    updated.skipped = newValue
                    if newValue {
                        updated.completed = false
                    }
                    onChange(updated)
                }
            ))
        }
        .padding()
        .background(insetBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stringBinding(_ keyPath: WritableKeyPath<WorkoutSet, String>) -> Binding<String> {
        Binding(
            get: { set[keyPath: keyPath] },
            set: { newValue in
                var updated = set
                updated[keyPath: keyPath] = newValue
                onChange(updated)
            }
        )
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<WorkoutSet, Double?>) -> Binding<Double> {
        Binding(
            get: { set[keyPath: keyPath] ?? 0 },
            set: { newValue in
                var updated = set
                updated[keyPath: keyPath] = newValue == 0 ? nil : newValue
                onChange(updated)
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<WorkoutSet, Int?>) -> Binding<Int> {
        Binding(
            get: { set[keyPath: keyPath] ?? 0 },
            set: { newValue in
                var updated = set
                updated[keyPath: keyPath] = newValue == 0 ? nil : newValue
                onChange(updated)
            }
        )
    }
}
