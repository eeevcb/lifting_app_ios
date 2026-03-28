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
            lastAutoSelectedDate: snapshot.lastAutoSelectedDate
        )

        let trainingData = TrainingDataSnapshot(
            drafts: snapshot.drafts,
            completedSessions: snapshot.completedSessions,
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
            let settings = try decoder.decode(AppSettingsSnapshot.self, from: settingsData)
            let training = try decoder.decode(TrainingDataSnapshot.self, from: trainingData)

            return AppSnapshot(
                programStartDate: settings.programStartDate,
                selectedWeek: settings.selectedWeek,
                selectedDay: settings.selectedDay,
                lastAutoSelectedDate: settings.lastAutoSelectedDate,
                drafts: training.drafts,
                completedSessions: training.completedSessions,
                liftStates: training.liftStates
            )
        } catch {
            return nil
        }
    }

    private func loadLegacySnapshot() -> AppSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
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
