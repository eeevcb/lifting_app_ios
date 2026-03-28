import SwiftUI

struct WorkoutScreen: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focusedField: WorkoutFieldFocus?
    @State private var activeRestTimer: ActiveRestTimer?
    @State private var activeNumericInput: WorkoutNumericInput?
    @State private var activeBackoffRecommendation: BackoffRecommendationPrompt?
    @State private var customRestMinutesText = ""
    @State private var visibleWeekPageIndex = 0
    @State private var isRestTimerCollapsed = false
    @State private var collapsedSections: Set<WorkoutSetType> = []

    private let cardBackground = Color(uiColor: .secondarySystemBackground)
    private let insetBackground = Color(uiColor: .systemBackground)

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let entry = model.currentEntry, let liftState = model.currentLiftState, let draft = model.currentDraft {
                        sessionHeader(entry: entry, liftState: liftState)
                        restTimerCard
                        selectionCard
                        autoTargetsCard(entry: entry, liftState: liftState)
                        engineInsightsCard(entry: entry, liftState: liftState)
                        if supportsStickingPoint(for: entry) {
                            stickingPointCard(entry: entry)
                        }
                        setActionsCard(isFinished: model.isCurrentWorkoutFinished)
                        workoutLogCard(draft: draft, isFinished: model.isCurrentWorkoutFinished)
                        finishWorkoutCard(entry: entry, liftState: liftState, isFinished: model.isCurrentWorkoutFinished)
                    } else {
                        ContentUnavailableView("No Workout", systemImage: "calendar.badge.exclamationmark", description: Text("There is no program entry for the selected day."))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Workout")
        .onAppear {
            if customRestMinutesText.isEmpty {
                customRestMinutesText = "\(max(1, model.lastUsedRestDurationSeconds / 60))"
            }
            syncVisibleWeekPage()
        }
        .onChange(of: model.selectedWeek) { _, _ in
            syncVisibleWeekPage()
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
        .sheet(item: $activeNumericInput) { input in
            NumericInputSheet(
                input: input,
                save: { value in
                    applyNumericInput(input, value: value)
                },
                cancel: { activeNumericInput = nil }
            )
        }
        .alert(
            activeBackoffRecommendation?.title ?? "Recommend Skipping Backoff?",
            isPresented: Binding(
                get: { activeBackoffRecommendation != nil },
                set: { isPresented in
                    if !isPresented {
                        activeBackoffRecommendation = nil
                    }
                }
            ),
            presenting: activeBackoffRecommendation
        ) { _ in
            Button("Skip Backoff", role: .destructive) {
                model.skipCurrentBackoffWork()
                activeBackoffRecommendation = nil
            }
            Button("Keep Backoff") {
                model.markBackoffRecommendationHandled()
                activeBackoffRecommendation = nil
            }
        } message: { prompt in
            Text(prompt.message)
        }
    }

    private var restTimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(
                title: "Rest Timer",
                subtitle: durationText(seconds: model.lastUsedRestDurationSeconds),
                isCollapsed: isRestTimerCollapsed,
                toggle: { isRestTimerCollapsed.toggle() }
            )

            if !isRestTimerCollapsed {
                metricBlock(title: "Saved Default", value: durationText(seconds: model.lastUsedRestDurationSeconds))

                HStack {
                    restPresetButton(minutes: 2)
                    restPresetButton(minutes: 3)
                    restPresetButton(minutes: 5)
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

                    Button("Save") {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Day")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(TrainingDay.allCases) { day in
                        selectionChip(
                            title: day.rawValue,
                            isSelected: model.selectedDay == day
                        ) {
                            model.select(week: model.selectedWeek, day: day)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Week")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        moveWeekPage(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .disabled(visibleWeekPageIndex == 0)

                    TabView(selection: $visibleWeekPageIndex) {
                        ForEach(Array(weekPages.enumerated()), id: \.offset) { index, weeks in
                            HStack(spacing: 8) {
                                ForEach(weeks, id: \.self) { week in
                                    selectionChip(
                                        title: "WK\(week)",
                                        isSelected: model.selectedWeek == week
                                    ) {
                                        model.select(week: week, day: model.selectedDay)
                                    }
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 44)

                    Button {
                        moveWeekPage(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .disabled(visibleWeekPageIndex >= max(weekPages.count - 1, 0))
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
                metricBlock(title: "Estimated 1RM", value: "\(Int(roundedFivePoundValue(liftState.estimatedOneRepMax))) lb")
                metricBlock(title: "Working Target", value: "\(Int(model.currentTargetWeight ?? 0)) lb")
            }

            HStack {
                metricBlock(title: "Fatigue", value: String(format: "%.1f", liftState.fatigueScore))
                metricBlock(title: "Engine Status", value: model.currentEngineStatusText)
            }

            HStack {
                metricBlock(title: "Training Max", value: "\(Int(roundedFivePoundValue(liftState.trainingMax))) lb")
                metricBlock(title: "Target Shift", value: percentString(from: model.currentTargetShiftPercent))
            }

            HStack {
                Text("Adjust \(entry.primaryLift.displayName) 1RM")
                Spacer()
                Stepper(
                    "\(Int(roundedFivePoundValue(liftState.estimatedOneRepMax)))",
                    value: Binding(
                        get: { Int(roundedFivePoundValue(liftState.estimatedOneRepMax)) },
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

    private func roundedFivePoundValue(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        return max(5, (value / 5).rounded() * 5)
    }

    private func engineInsightsCard(entry: ProgramEntry, liftState: LiftState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engine Insights")
                .font(.headline)

            if let session = model.currentCompletedSession {
                let fatigue = session.fatigue

                HStack {
                    metricBlock(title: "Ramp Effort RPE", value: effortString(actual: fatigue.actualRampEffort, expected: fatigue.expectedRampEffort))
                    metricBlock(title: "Working Set Effort RPE", value: effortString(actual: fatigue.actualTopSetEffort, expected: fatigue.expectedTopSetEffort))
                }

                HStack {
                    metricBlock(title: "Overall Delta", value: signedNumberString(fatigue.effortDelta))
                    metricBlock(title: "Next Target", value: session.nextTargetWeight.map { "\(Int($0)) lb" } ?? "--")
                }

                VStack(alignment: .leading, spacing: 8) {
                    insightRow(label: "Progression", value: fatigue.recommendation.displayName)
                    insightRow(label: "Backoff", value: backoffStatus(for: session))
                    insightRow(label: "Reason", value: fatigue.backoffDecisionReason)
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))

                Text("Effort compares the average recorded RPE for completed sets against the target RPE the engine expected for this workout prescription.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Target RPE changes with the program. Higher-intensity prescriptions like 3x3, 2x2, openers, and max singles carry higher working-set RPE targets than 4x8 or 5x5 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Progression stays neutral without RPE data, and skipped sets alone do not trigger deload logic.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Finish this workout to see how the engine compares actual effort to target effort, decides on backoff work, and seeds the next target.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("These effort targets use the RPE 1-10 scale. The target changes with the workout prescription, so 4x8 and 5x5 days are easier than 3x3, 2x2, openers, and max-single days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func stickingPointCard(entry: ProgramEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sticking Point Feedback")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(StickingPoint.allCases) { stickingPoint in
                    selectionChip(
                        title: stickingPoint.displayName,
                        isSelected: model.currentStickingPoint == stickingPoint
                    ) {
                        model.updateCurrentStickingPoint(model.currentStickingPoint == stickingPoint ? nil : stickingPoint)
                    }
                }
            }

            if let recommendedVariationName = model.currentRecommendedVariationName {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended Variation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(recommendedVariationName)
                        .font(.subheadline.weight(.semibold))
                    Text("Tap “Use Suggested” on any variation row to apply this recommendation without changing the others.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 14))
            } else {
                Text("Pick where the lift felt hardest to get a variation recommendation for this workout.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .disabled(model.isCurrentWorkoutFinished)
        .opacity(model.isCurrentWorkoutFinished ? 0.75 : 1)
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

            ForEach(visibleSetTypes(for: draft), id: \.self) { setType in
                let sectionSets = draft.sets.sortedForDisplay().filter { $0.setType == setType }

                VStack(alignment: .leading, spacing: 12) {
                    collapsibleHeader(
                        title: setType.displayName,
                        subtitle: "\(sectionSets.count) set\(sectionSets.count == 1 ? "" : "s")",
                        isCollapsed: collapsedSections.contains(setType),
                        toggle: { toggleSection(setType) }
                    )

                    if !collapsedSections.contains(setType) {
                        ForEach(sectionSets) { set in
                            WorkoutSetRow(
                                set: set,
                                variationOptions: ProgramDefinition.variationNames(for: draft.programEntry.primaryLift),
                                recommendedVariationName: model.currentRecommendedVariationName,
                                isWorkoutFinished: isFinished,
                                onPresentNumericInput: { input in
                                    activeNumericInput = input
                                },
                                onVariationChange: { profileName in
                                    model.updateVariation(for: set.id, to: profileName)
                                },
                                onApplyRecommendedVariation: {
                                    model.applyRecommendedVariation(to: set.id)
                                },
                                onChange: { updatedSet, didCompleteNow in
                                    model.updateSet(set.id) { current in
                                        current = updatedSet
                                    }
                                    let didPresentBackoffRecommendation = maybePresentBackoffRecommendation()
                                    if didCompleteNow, !didPresentBackoffRecommendation, model.autoStartRestTimerOnCompletion {
                                        focusedField = nil
                                        presentRestTimer(seconds: model.lastUsedRestDurationSeconds)
                                    }
                                },
                                onDelete: {
                                    model.removeSet(set.id)
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(insetBackground, in: RoundedRectangle(cornerRadius: 16))
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

    private func selectionChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.blue.opacity(0.18) : insetBackground, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(isSelected ? .blue : .primary)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
        }
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
        "\(compactRPE(actual))/\(compactRPE(expected))"
    }

    private func collapsibleHeader(title: String, subtitle: String? = nil, isCollapsed: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
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

    private func applyNumericInput(_ input: WorkoutNumericInput, value: Double) {
        model.updateSet(input.setID) { current in
            switch input.field {
            case .weight:
                current.weight = value == 0 ? nil : value
            case .reps:
                current.reps = max(1, Int(value.rounded()))
            case .rpe:
                current.rpe = value == 0 ? nil : value
                if value > 0 {
                    current.completed = true
                    current.skipped = false
                }
            case .chainCount:
                current.chainCountPerSide = max(0, Int(value.rounded()))
            }
        }

        activeNumericInput = nil

        let shouldEvaluateBackoff = input.field == .rpe && input.setType == .topSet
        let shouldAutoStartTimer = input.field == .rpe && value > 0 && model.autoStartRestTimerOnCompletion

        DispatchQueue.main.async {
            let didPresentBackoffRecommendation = shouldEvaluateBackoff ? maybePresentBackoffRecommendation() : false

            if shouldAutoStartTimer, !didPresentBackoffRecommendation {
                presentRestTimer(seconds: model.lastUsedRestDurationSeconds)
            }
        }
    }

    private func maybePresentBackoffRecommendation() -> Bool {
        guard activeBackoffRecommendation == nil, !model.isCurrentWorkoutFinished else { return false }
        guard let prompt = model.currentBackoffRecommendation() else { return false }
        activeBackoffRecommendation = prompt
        return true
    }

    private var weekPages: [[Int]] {
        stride(from: 0, to: model.weeks.count, by: 3).map { start in
            Array(model.weeks[start..<min(start + 3, model.weeks.count)])
        }
    }

    private func visibleSetTypes(for draft: SessionDraft) -> [WorkoutSetType] {
        WorkoutSetType.allCases.filter { setType in
            draft.sets.contains { $0.setType == setType }
        }
    }

    private func toggleSection(_ setType: WorkoutSetType) {
        if collapsedSections.contains(setType) {
            collapsedSections.remove(setType)
        } else {
            collapsedSections.insert(setType)
        }
    }

    private func moveWeekPage(by offset: Int) {
        let maxIndex = max(weekPages.count - 1, 0)
        visibleWeekPageIndex = min(max(visibleWeekPageIndex + offset, 0), maxIndex)
    }

    private func syncVisibleWeekPage() {
        guard let pageIndex = weekPages.firstIndex(where: { $0.contains(model.selectedWeek) }) else { return }
        visibleWeekPageIndex = pageIndex
    }

    private func durationText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func backoffStatus(for session: CompletedSession) -> String {
        let backoffSets = session.sets.filter { $0.setType == .backoff }
        guard !backoffSets.isEmpty else { return "N/A" }
        if backoffSets.contains(where: \.skipped) {
            return "Skipped"
        }
        if backoffSets.allSatisfy({ $0.completed && !$0.skipped }) {
            return "Completed"
        }
        return "Kept"
    }

    private func supportsStickingPoint(for entry: ProgramEntry) -> Bool {
        [.squat, .bench, .deadlift].contains(entry.primaryLift)
    }

    private func compactRPE(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

private enum WorkoutFieldFocus: Hashable {
    case customRestMinutes
}

private enum WorkoutNumericField: Hashable {
    case weight
    case reps
    case rpe
    case chainCount
}

private struct WorkoutNumericInput: Identifiable {
    let setID: UUID
    let setType: WorkoutSetType
    let field: WorkoutNumericField
    let title: String
    let values: [Double]
    let selectedValue: Double

    var id: String {
        "\(setID.uuidString)-\(title)"
    }
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

            if let stickingPoint = session.stickingPoint {
                summaryMetric(title: "Sticking Point", value: stickingPoint.displayName)
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
                summaryMetric(title: "Ramp Effort RPE", value: effortString(actual: session.fatigue.actualRampEffort, expected: session.fatigue.expectedRampEffort))
                summaryMetric(title: "Working Set Effort RPE", value: effortString(actual: session.fatigue.actualTopSetEffort, expected: session.fatigue.expectedTopSetEffort))
            }

            Text("Ramp effort is the average recorded RPE from completed ramp sets against target ramp RPE. Working-set effort is the same comparison for completed working sets, and the target changes with the workout prescription.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                detailRow(title: "Overall Delta", value: signedNumberString(session.fatigue.effortDelta))
                detailRow(title: "Backoff", value: backoffStatus(for: session))
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
        "\(compactRPE(actual))/\(compactRPE(expected))"
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

    private func compactRPE(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func backoffStatus(for session: CompletedSession) -> String {
        let backoffSets = session.sets.filter { $0.setType == .backoff }
        guard !backoffSets.isEmpty else { return "N/A" }
        if backoffSets.contains(where: \.skipped) {
            return "Skipped"
        }
        if backoffSets.allSatisfy({ $0.completed && !$0.skipped }) {
            return "Completed"
        }
        return "Kept"
    }
}

private struct WorkoutSetRow: View {
    let set: WorkoutSet
    let variationOptions: [String]
    let recommendedVariationName: String?
    let isWorkoutFinished: Bool
    let onPresentNumericInput: (WorkoutNumericInput) -> Void
    let onVariationChange: (String) -> Void
    let onApplyRecommendedVariation: () -> Void
    let onChange: (WorkoutSet, Bool) -> Void
    let onDelete: () -> Void

    private let insetBackground = Color(uiColor: .systemBackground)
    private var isLocked: Bool { self.isWorkoutFinished || self.set.completed || self.set.skipped }
    private var canDelete: Bool { !isWorkoutFinished && set.setType != .topSet }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(set.setOrder). \(set.setType.displayName)")
                    .font(.headline)
                Spacer()
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Exercise")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if set.setType == .variation, !variationOptions.isEmpty, !isLocked {
                    variationMenu
                } else {
                    lockedValue(set.exerciseName)
                }
            }

            HStack {
                labeledField(title: "Weight", readOnlyValue: weightDisplayValue) {
                    inputButton(weightDisplayValue == "--" ? "Set Weight" : weightDisplayValue) {
                        onPresentNumericInput(
                            WorkoutNumericInput(
                                setID: set.id,
                                setType: set.setType,
                                field: .weight,
                                title: "Weight",
                                values: stride(from: 0.0, through: 1000.0, by: 5.0).map { $0 },
                                selectedValue: (set.weight ?? 0).rounded(.toNearestOrAwayFromZero)
                            )
                        )
                    }
                }

                labeledField(title: "Reps", readOnlyValue: set.reps.map(String.init) ?? "--") {
                    inputButton(set.reps.map(String.init) ?? "Set Reps") {
                        onPresentNumericInput(
                            WorkoutNumericInput(
                                setID: set.id,
                                setType: set.setType,
                                field: .reps,
                                title: "Reps",
                                values: Array(1...10).map(Double.init),
                                selectedValue: Double(set.reps ?? 1)
                            )
                        )
                    }
                }

                labeledField(title: "RPE", readOnlyValue: set.rpe.map { String(format: "%.1f", $0) } ?? "--") {
                    inputButton(set.rpe.map(compactDisplay) ?? "Set RPE") {
                        onPresentNumericInput(
                            WorkoutNumericInput(
                                setID: set.id,
                                setType: set.setType,
                                field: .rpe,
                                title: "RPE",
                                values: stride(from: 0.5, through: 10.0, by: 0.5).map { $0 },
                                selectedValue: max(set.rpe ?? 0.5, 0.5)
                            )
                        )
                    }
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

    private func inputButton(_ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    @ViewBuilder
    private var variationDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let helperText = ProgramDefinition.variationProfile(named: set.variationProfileName ?? set.exerciseName)?.helperText {
                Label(helperText, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let chainUnitWeightPerSide = set.chainUnitWeightPerSide {
                HStack {
                    labeledField(title: "Chains / Side", readOnlyValue: "\(set.chainCountPerSide)") {
                        inputButton("\(set.chainCountPerSide)") {
                            onPresentNumericInput(
                                WorkoutNumericInput(
                                    setID: set.id,
                                    setType: set.setType,
                                    field: .chainCount,
                                    title: "Chains / Side",
                                    values: Array(0...20).map(Double.init),
                                    selectedValue: Double(set.chainCountPerSide)
                                )
                            )
                        }
                    }

                    metricDetail(title: "Chain Load", value: "\(Int(chainUnitWeightPerSide * 2 * Double(set.chainCountPerSide))) lb")
                    metricDetail(title: "Top-End Load", value: "\(Int(set.totalDisplayedLoad)) lb")
                }

                Label("Chain count is per side. 1 means one 15 lb chain on each side, for 30 lb total added chain weight.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                metricDetail(title: "Total Load", value: set.totalDisplayedLoad > 0 ? "\(Int(set.totalDisplayedLoad)) lb" : "--")
            }

            if let recommendedVariationName, recommendedVariationName != (set.variationProfileName ?? set.exerciseName), !isLocked {
                Button("Use Suggested: \(recommendedVariationName)") {
                    onApplyRecommendedVariation()
                }
                .buttonStyle(.bordered)
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

    private var variationMenu: some View {
        Menu {
            ForEach(variationOptions, id: \.self) { option in
                Button(option) {
                    onVariationChange(option)
                }
            }
        } label: {
            HStack {
                Text(set.exerciseName)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.primary)
        }
        .disabled(isLocked)
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

    private func compactDisplay(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

private struct NumericInputSheet: View {
    let input: WorkoutNumericInput
    let save: (Double) -> Void
    let cancel: () -> Void

    @State private var selectedValue: Double

    init(input: WorkoutNumericInput, save: @escaping (Double) -> Void, cancel: @escaping () -> Void) {
        self.input = input
        self.save = save
        self.cancel = cancel
        _selectedValue = State(initialValue: input.values.contains(input.selectedValue) ? input.selectedValue : (input.values.first ?? input.selectedValue))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker(input.title, selection: $selectedValue) {
                    ForEach(input.values, id: \.self) { value in
                        Text(display(value))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Button("Save") {
                    save(selectedValue)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle(input.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: cancel)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func display(_ value: Double) -> String {
        switch input.field {
        case .weight:
            return "\(Int(value)) lb"
        case .reps, .chainCount:
            return "\(Int(value))"
        case .rpe:
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(format: "%.1f", value)
        }
    }
}
