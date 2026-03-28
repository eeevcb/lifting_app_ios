import SwiftUI

struct WorkoutScreen: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focusedField: WorkoutFieldFocus?
    @State private var activeRestTimer: ActiveRestTimer?
    @State private var customRestMinutesText = ""

    private let cardBackground = Color(uiColor: .secondarySystemBackground)
    private let insetBackground = Color(uiColor: .systemBackground)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let entry = model.currentEntry, let liftState = model.currentLiftState, let draft = model.currentDraft {
                    sessionHeader(entry: entry, liftState: liftState)
                    restTimerCard
                    selectionCard
                    autoTargetsCard(entry: entry, liftState: liftState)
                    engineInsightsCard(entry: entry, liftState: liftState)
                    variationCard(entry: entry, draft: draft, isFinished: model.isCurrentWorkoutFinished)
                    setActionsCard(isFinished: model.isCurrentWorkoutFinished)
                    workoutLogCard(draft: draft, isFinished: model.isCurrentWorkoutFinished)
                    finishWorkoutCard(entry: entry, liftState: liftState, isFinished: model.isCurrentWorkoutFinished)
                } else {
                    ContentUnavailableView("No Workout", systemImage: "calendar.badge.exclamationmark", description: Text("There is no program entry for the selected day."))
                }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .navigationTitle("Workout")
        .onAppear {
            if customRestMinutesText.isEmpty {
                customRestMinutesText = "\(max(1, model.lastUsedRestDurationSeconds / 60))"
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { model.lastCompletionSummary != nil },
                set: { isPresented in
                    if !isPresented {
                        model.dismissCompletionSummary()
                    }
                }
            )
        ) {
            if let session = model.lastCompletionSummary {
                CompletionSummarySheet(
                    session: session,
                    dismiss: model.dismissCompletionSummary
                )
            }
        }
        .sheet(item: $activeRestTimer) { timer in
            RestTimerSheet(
                timer: timer,
                cancel: { activeRestTimer = nil }
            )
        }
    }

    private var restTimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rest Timer")
                .font(.headline)

            HStack {
                metricBlock(title: "Saved Default", value: durationText(seconds: model.lastUsedRestDurationSeconds))
                metricBlock(title: "Auto Start", value: model.autoStartRestTimerOnCompletion ? "On" : "Off")
            }

            HStack {
                restPresetButton(minutes: 2)
                restPresetButton(minutes: 3)
                restPresetButton(minutes: 5)
                Button("\(max(1, model.lastUsedRestDurationSeconds / 60)) Min") {
                    focusedField = nil
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Minutes", text: Binding(
                        get: { customRestMinutesText },
                        set: { newValue in
                            customRestMinutesText = newValue.filter(\.isNumber)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .customRestMinutes)
                }

                Button("Save Default") {
                    saveCustomRestDuration()
                }
                .buttonStyle(.bordered)

                Button("Start") {
                    focusedField = nil
                    presentRestTimer(seconds: model.lastUsedRestDurationSeconds)
                }
                .buttonStyle(.borderedProminent)
            }

            Toggle("Automatically start timer on workout completion", isOn: Binding(
                get: { model.autoStartRestTimerOnCompletion },
                set: { model.updateAutoStartRestTimerOnCompletion($0) }
            ))
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
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
                metricBlock(title: "Progression", value: liftState.lastRecommendation.displayName)
            }

            HStack {
                metricBlock(title: "Training Max", value: "\(Int(liftState.trainingMax)) lb")
                metricBlock(title: "Target Shift", value: percentString(from: liftState.lastTargetAdjustmentPercent))
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

    private func engineInsightsCard(entry: ProgramEntry, liftState: LiftState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engine Insights")
                .font(.headline)

            if let session = model.currentCompletedSession ?? model.latestCompletedSessionForCurrentLift {
                let fatigue = session.fatigue

                HStack {
                    metricBlock(title: "Ramp Effort", value: effortString(actual: fatigue.actualRampEffort, expected: fatigue.expectedRampEffort))
                    metricBlock(title: "\(WorkoutSetType.topSet.displayName) Effort", value: effortString(actual: fatigue.actualTopSetEffort, expected: fatigue.expectedTopSetEffort))
                }

                HStack {
                    metricBlock(title: "Overall Delta", value: signedNumberString(fatigue.effortDelta))
                    metricBlock(title: "Next Target", value: session.nextTargetWeight.map { "\(Int($0)) lb" } ?? "--")
                }

                VStack(alignment: .leading, spacing: 8) {
                    insightRow(label: "Progression", value: fatigue.recommendation.displayName)
                    insightRow(label: "Backoff", value: fatigue.skipBackoffWork ? "Skip" : "Keep")
                    insightRow(label: "Reason", value: fatigue.backoffDecisionReason)
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))

                Text("Effort compares the average recorded RPE for completed sets against the target RPE the engine expected for this phase.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Progression stays neutral without RPE data, and skipped sets alone do not trigger deload logic.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if session.programEntry.key != entry.key {
                    Text("Showing the latest completed \(session.programEntry.primaryLift.displayName) session until this workout is finished.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Finish a workout to see how the engine compares expected and actual effort, decides on backoff work, and seeds the next target.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func variationCard(entry: ProgramEntry, draft: SessionDraft, isFinished: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Variation")
                .font(.headline)

            Picker("Accessory", selection: Binding(
                get: { draft.selectedVariation.profileName },
                set: { model.updateVariation($0) }
            )) {
                ForEach(ProgramDefinition.variationNames(for: entry.primaryLift), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .disabled(isFinished)

            if let profile = ProgramDefinition.variationProfile(named: draft.selectedVariation.profileName, for: entry.primaryLift) {
                Text(profile.helperText ?? "Variation defaults are seeded from the day’s working target and can still be edited set by set.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("This selection is kept with the session draft and can later feed variation-impact analytics.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .opacity(isFinished ? 0.7 : 1)
    }

    private func setActionsCard(isFinished: Bool) -> some View {
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
        .disabled(isFinished)
        .opacity(isFinished ? 0.7 : 1)
    }

    private func workoutLogCard(draft: SessionDraft, isFinished: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Log")
                .font(.headline)

            ForEach(draft.sets.sortedForDisplay()) { set in
                WorkoutSetRow(
                    set: set,
                    isWorkoutFinished: isFinished,
                    focusedField: $focusedField,
                    onChange: { updatedSet, didCompleteNow in
                        model.updateSet(set.id) { current in
                            current = updatedSet
                        }
                        if didCompleteNow, model.autoStartRestTimerOnCompletion {
                            focusedField = nil
                            presentRestTimer(seconds: model.lastUsedRestDurationSeconds)
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

    private func finishWorkoutCard(entry: ProgramEntry, liftState: LiftState, isFinished: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isFinished ? "Workout Closed" : "Finish Workout")
                .font(.headline)
            Text(isFinished
                 ? "This session is finished and locked. Review the summary or reopen it to make edits."
                 : "Completing a session runs the fatigue engine, updates \(entry.primaryLift.displayName) state, stores analytics, and seeds the next target.")
            .foregroundStyle(.secondary)

            if isFinished {
                HStack {
                    Button("Review Summary") {
                        model.reviewCurrentWorkoutSummary()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reopen Workout") {
                        model.reopenCurrentWorkout()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Finish Workout") {
                    model.finishWorkout()
                }
                .buttonStyle(.borderedProminent)
                .tint(liftState.lastRecommendation == .deload ? .orange : .blue)
            }
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

    private func insightRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func effortString(actual: Double, expected: Double) -> String {
        String(format: "%.1f actual vs %.1f expected", actual, expected)
    }

    private func percentString(from value: Double) -> String {
        let percent = value * 100
        if percent > 0 {
            return String(format: "+%.0f%%", percent)
        }
        return String(format: "%.0f%%", percent)
    }

    private func signedNumberString(_ value: Double) -> String {
        if value > 0 {
            return String(format: "+%.2f", value)
        }
        return String(format: "%.2f", value)
    }

    private func restPresetButton(minutes: Int) -> some View {
        Button("\(minutes) Min") {
            focusedField = nil
            let seconds = minutes * 60
            model.updateLastUsedRestDuration(seconds: seconds)
            customRestMinutesText = "\(minutes)"
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func saveCustomRestDuration() {
        let customMinutes = max(1, Int(customRestMinutesText) ?? max(1, model.lastUsedRestDurationSeconds / 60))
        let seconds = customMinutes * 60
        customRestMinutesText = "\(customMinutes)"
        focusedField = nil
        model.updateLastUsedRestDuration(seconds: seconds)
    }

    private func presentRestTimer(seconds: Int) {
        activeRestTimer = ActiveRestTimer(seconds: seconds)
    }

    private func durationText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private enum WorkoutFieldFocus: Hashable {
    case customRestMinutes
    case weight(UUID)
    case reps(UUID)
    case rpe(UUID)
    case chainCount(UUID)
}

private struct ActiveRestTimer: Identifiable {
    let id = UUID()
    let startedAt: Date
    let durationSeconds: Int

    init(seconds: Int) {
        self.startedAt = .now
        self.durationSeconds = seconds
    }

    var endDate: Date {
        startedAt.addingTimeInterval(TimeInterval(durationSeconds))
    }
}

private struct RestTimerSheet: View {
    let timer: ActiveRestTimer
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remainingSeconds = max(0, Int(timer.endDate.timeIntervalSince(context.date).rounded()))

                VStack(spacing: 24) {
                    Text("Rest Timer")
                        .font(.largeTitle.bold())

                    Text(durationText(seconds: remainingSeconds))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(remainingSeconds == 0 ? "Rest complete" : "Timer is running")
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        Button(remainingSeconds == 0 ? "Close" : "Cancel Timer", action: cancel)
                            .buttonStyle(.borderedProminent)

                        if remainingSeconds > 0 {
                            Text("Closing early stops this timer only and keeps your saved default unchanged.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Rest")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close", action: cancel)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func durationText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct CompletionSummarySheet: View {
    let session: CompletedSession
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout Complete")
                            .font(.largeTitle.bold())
                        Text("\(session.programEntry.primaryLift.displayName) - Week \(session.programEntry.week) \(session.programEntry.day.rawValue)")
                            .foregroundStyle(.secondary)
                    }

                    summaryCard
                    fatigueCard
                    actionCard
                }
                .padding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: dismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Outcome")
                .font(.headline)

            HStack {
                summaryMetric(title: "Volume", value: "\(Int(session.summary.totalVolume)) lb")
                summaryMetric(title: "Best e1RM", value: session.summary.bestEstimatedOneRepMax.map { "\(Int($0)) lb" } ?? "--")
            }

            HStack {
                summaryMetric(title: "Completed Sets", value: "\(session.summary.completedSetCount)")
                summaryMetric(title: "Next Target", value: session.nextTargetWeight.map { "\(Int($0)) lb" } ?? "--")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var fatigueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engine Call")
                .font(.headline)

            HStack {
                summaryMetric(title: "Progression", value: session.fatigue.recommendation.displayName)
                summaryMetric(title: "Target Shift", value: percentString(session.fatigue.targetAdjustmentPercent))
            }

            HStack {
                summaryMetric(title: "Ramp Effort", value: effortString(actual: session.fatigue.actualRampEffort, expected: session.fatigue.expectedRampEffort))
                summaryMetric(title: "\(WorkoutSetType.topSet.displayName) Effort", value: effortString(actual: session.fatigue.actualTopSetEffort, expected: session.fatigue.expectedTopSetEffort))
            }

            Text("Ramp effort is the average recorded RPE from completed ramp sets against target ramp RPE. Working-set effort is the same comparison for completed working sets.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                detailRow(title: "Overall Delta", value: signedNumberString(session.fatigue.effortDelta))
                detailRow(title: "Backoff", value: session.fatigue.skipBackoffWork ? "Skipped" : "Kept")
                detailRow(title: "Reason", value: session.fatigue.backoffDecisionReason)
            }
            .padding()
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Happens Next")
                .font(.headline)
            Text("The lift state has been updated, future drafts for this lift were regenerated, and the next session target now reflects this result.")
                .foregroundStyle(.secondary)
            Button("Back to Workout", action: dismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func effortString(actual: Double, expected: Double) -> String {
        String(format: "%.1f actual vs %.1f expected", actual, expected)
    }

    private func percentString(_ value: Double) -> String {
        let percent = value * 100
        if percent > 0 {
            return String(format: "+%.0f%%", percent)
        }
        return String(format: "%.0f%%", percent)
    }

    private func signedNumberString(_ value: Double) -> String {
        if value > 0 {
            return String(format: "+%.2f", value)
        }
        return String(format: "%.2f", value)
    }
}

private struct WorkoutSetRow: View {
    let set: WorkoutSet
    let isWorkoutFinished: Bool
    @Binding var focusedField: WorkoutFieldFocus?
    let onChange: (WorkoutSet, Bool) -> Void
    let onDelete: () -> Void

    private let insetBackground = Color(uiColor: .systemBackground)
    private var isLocked: Bool { self.isWorkoutFinished || self.set.completed || self.set.skipped }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(set.setOrder). \(set.setType.displayName)")
                    .font(.headline)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .disabled(isWorkoutFinished)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Exercise")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                lockedValue(set.exerciseName)
            }

            HStack {
                labeledField(
                    title: "Weight",
                    readOnlyValue: weightDisplayValue
                ) {
                    TextField("Weight", value: doubleBinding(\.weight, maxValue: nil, autoCompleteWhenPositive: false), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight(set.id))
                        .disabled(isLocked)
                }

                labeledField(
                    title: "Reps",
                    readOnlyValue: set.reps.map(String.init) ?? "--"
                ) {
                    TextField("Reps", value: intBinding(\.reps, maxValue: 50), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .reps(set.id))
                        .disabled(isLocked)
                }

                labeledField(
                    title: "RPE",
                    readOnlyValue: set.rpe.map { String(format: "%.1f", $0) } ?? "--"
                ) {
                    TextField("RPE", value: doubleBinding(\.rpe, maxValue: 10, autoCompleteWhenPositive: true), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .rpe(set.id))
                        .disabled(isLocked)
                }
            }

            if set.setType == .variation {
                variationDetails
            }

            Toggle("Completed", isOn: Binding(
                get: { set.completed },
                set: { newValue in
                    var updated = set
                    let didCompleteNow = newValue && !set.completed
                    updated.completed = newValue
                    if newValue {
                        updated.skipped = false
                        focusedField = nil
                    }
                    onChange(updated, didCompleteNow)
                }
            ))
            .disabled(isWorkoutFinished)

            Toggle("Skipped", isOn: Binding(
                get: { set.skipped },
                set: { newValue in
                    var updated = set
                    updated.skipped = newValue
                    if newValue {
                        updated.completed = false
                    }
                    onChange(updated, false)
                }
            ))
            .disabled(isWorkoutFinished)
        }
        .padding()
        .background(insetBackground, in: RoundedRectangle(cornerRadius: 16))
        .opacity(set.skipped ? 0.6 : 1)
    }

    @ViewBuilder
    private func labeledField<Content: View>(title: String, readOnlyValue: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLocked {
                lockedValue(readOnlyValue)
            } else {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lockedValue(_ value: String) -> some View {
        Text(value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var variationDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let chainUnitWeightPerSide = set.chainUnitWeightPerSide {
                HStack {
                    labeledField(
                        title: "Chains / Side",
                        readOnlyValue: "\(set.chainCountPerSide)"
                    ) {
                        TextField("Chains / Side", value: intBinding(\.chainCountPerSide, maxValue: 20), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .chainCount(set.id))
                            .disabled(isLocked)
                    }

                    metricDetail(title: "Chain Load", value: "\(Int(chainUnitWeightPerSide * 2 * Double(set.chainCountPerSide))) lb")
                    metricDetail(title: "Top-End Load", value: "\(Int(set.totalDisplayedLoad)) lb")
                }

                Label("Chain count is per side. 1 means one 15 lb chain on each side, for 30 lb total added chain weight.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if set.variationProfileName == "Pull Ups" {
                Label("Defaults to 0 added load. Add weight only if using a belt.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                metricDetail(title: "Total Load", value: set.totalDisplayedLoad > 0 ? "\(Int(set.totalDisplayedLoad)) lb" : "--")
            }
        }
    }

    private var weightDisplayValue: String {
        if set.setType == .variation, set.totalChainLoad > 0 {
            return "\(Int(set.weight ?? 0)) lb straight + \(Int(set.totalChainLoad)) lb chains"
        }
        if set.variationProfileName == "Pull Ups", (set.weight ?? 0) == 0 {
            return "0.0"
        }
        if let weight = set.weight {
            return String(format: "%.1f", weight)
        }
        return "--"
    }

    private func metricDetail(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func doubleBinding(
        _ keyPath: WritableKeyPath<WorkoutSet, Double?>,
        maxValue: Double?,
        autoCompleteWhenPositive: Bool
    ) -> Binding<Double> {
        Binding(
            get: { set[keyPath: keyPath] ?? 0 },
            set: { newValue in
                var updated = set
                let clampedValue = max(0, maxValue.map { min(newValue, $0) } ?? newValue)
                let didCompleteNow = autoCompleteWhenPositive && clampedValue > 0 && !set.completed
                updated[keyPath: keyPath] = clampedValue == 0 ? nil : clampedValue
                if autoCompleteWhenPositive, clampedValue > 0 {
                    updated.completed = true
                    updated.skipped = false
                    focusedField = nil
                }
                onChange(updated, didCompleteNow)
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<WorkoutSet, Int?>, maxValue: Int) -> Binding<Int> {
        Binding(
            get: { set[keyPath: keyPath] ?? 0 },
            set: { newValue in
                var updated = set
                let clampedValue = max(0, min(newValue, maxValue))
                updated[keyPath: keyPath] = clampedValue == 0 ? nil : clampedValue
                onChange(updated, false)
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<WorkoutSet, Int>, maxValue: Int) -> Binding<Int> {
        Binding(
            get: { set[keyPath: keyPath] },
            set: { newValue in
                var updated = set
                updated[keyPath: keyPath] = max(0, min(newValue, maxValue))
                onChange(updated, false)
            }
        )
    }
}
