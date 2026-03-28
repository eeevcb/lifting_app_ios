import Foundation

struct PersistenceController {
    private let storageFolderName = "LiftingAppStorage"
    private let legacyStorageKey = "lifting-app-ios-snapshot-v1"

    func load() -> AppSnapshot? {
        if let snapshot = loadFromDisk() {
            return snapshot
        }

        guard let legacy = loadLegacySnapshot() else { return nil }
        save(snapshot: legacy)
        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        return legacy
    }

    func save(snapshot: AppSnapshot) {
        let settings = AppSettingsSnapshot(
            programStartDate: snapshot.programStartDate,
            selectedWeek: snapshot.selectedWeek,
            selectedDay: snapshot.selectedDay,
            lastAutoSelectedDate: snapshot.lastAutoSelectedDate,
            lastUsedRestDurationSeconds: snapshot.lastUsedRestDurationSeconds,
            autoStartRestTimerOnCompletion: snapshot.autoStartRestTimerOnCompletion
        )

        let trainingData = TrainingDataSnapshot(
            drafts: snapshot.drafts,
            activeRun: snapshot.activeRun,
            archivedRuns: snapshot.archivedRuns,
            liftStates: snapshot.liftStates
        )

        do {
            let directory = try storageDirectory()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            try write(encoder.encode(settings), to: directory.appending(path: "settings.json"))
            try write(encoder.encode(trainingData), to: directory.appending(path: "training-data.json"))
        } catch {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(data, forKey: legacyStorageKey)
        }
    }

    private func loadFromDisk() -> AppSnapshot? {
        do {
            let directory = try storageDirectory()
            let settingsURL = directory.appending(path: "settings.json")
            let trainingDataURL = directory.appending(path: "training-data.json")
            let decoder = JSONDecoder()

            let settingsData = try Data(contentsOf: settingsURL)
            let trainingData = try Data(contentsOf: trainingDataURL)

            if let settings = try? decoder.decode(AppSettingsSnapshot.self, from: settingsData),
               let training = try? decoder.decode(TrainingDataSnapshot.self, from: trainingData) {
                return AppSnapshot(
                    programStartDate: settings.programStartDate,
                    selectedWeek: settings.selectedWeek,
                    selectedDay: settings.selectedDay,
                    lastAutoSelectedDate: settings.lastAutoSelectedDate,
                    lastUsedRestDurationSeconds: settings.lastUsedRestDurationSeconds,
                    autoStartRestTimerOnCompletion: settings.autoStartRestTimerOnCompletion,
                    drafts: training.drafts,
                    activeRun: training.activeRun,
                    archivedRuns: training.archivedRuns,
                    liftStates: training.liftStates
                )
            }

            let legacySettings = try decoder.decode(LegacyAppSettingsSnapshot.self, from: settingsData)
            let legacyTraining = try decoder.decode(LegacyTrainingDataSnapshot.self, from: trainingData)
            return migratedSnapshot(
                programStartDate: legacySettings.programStartDate,
                selectedWeek: legacySettings.selectedWeek,
                selectedDay: legacySettings.selectedDay,
                lastAutoSelectedDate: legacySettings.lastAutoSelectedDate,
                drafts: legacyTraining.drafts,
                completedSessions: legacyTraining.completedSessions,
                liftStates: legacyTraining.liftStates
            )
        } catch {
            return nil
        }
    }

    private func loadLegacySnapshot() -> AppSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey) else { return nil }
        let decoder = JSONDecoder()

        if let snapshot = try? decoder.decode(AppSnapshot.self, from: data) {
            return snapshot
        }

        guard let legacy = try? decoder.decode(LegacyAppSnapshot.self, from: data) else { return nil }
        return migratedSnapshot(
            programStartDate: legacy.programStartDate,
            selectedWeek: legacy.selectedWeek,
            selectedDay: legacy.selectedDay,
            lastAutoSelectedDate: legacy.lastAutoSelectedDate,
            drafts: legacy.drafts,
            completedSessions: legacy.completedSessions,
            liftStates: legacy.liftStates
        )
    }

    private func migratedSnapshot(
        programStartDate: Date,
        selectedWeek: Int,
        selectedDay: TrainingDay,
        lastAutoSelectedDate: Date?,
        drafts: [String: SessionDraft],
        completedSessions: [CompletedSession],
        liftStates: [LiftType: LiftState]
    ) -> AppSnapshot {
        AppSnapshot(
            programStartDate: programStartDate,
            selectedWeek: selectedWeek,
            selectedDay: selectedDay,
            lastAutoSelectedDate: lastAutoSelectedDate,
            lastUsedRestDurationSeconds: 180,
            autoStartRestTimerOnCompletion: true,
            drafts: drafts,
            activeRun: ProgramRun(startedAt: programStartDate, programStartDate: programStartDate, completedSessions: completedSessions),
            archivedRuns: [],
            liftStates: liftStates
        )
    }

    private func storageDirectory() throws -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseDirectory.appending(path: storageFolderName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}
