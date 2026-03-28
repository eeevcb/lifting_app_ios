import Foundation

struct PersistenceController {
    private let storageKey = "lifting-app-ios-snapshot-v1"

    func load() -> AppSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    func save(snapshot: AppSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
