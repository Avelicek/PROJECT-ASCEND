import Foundation

struct WorkoutDraftStorage {
    let url: URL
    static func production() throws -> WorkoutDraftStorage {
        let folder = try OwnerStoreLocation.selectedFolder()
        return WorkoutDraftStorage(url: folder.appendingPathComponent("active-workout-v1.json"))
    }
    func read() throws -> LiveWorkout? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let value = try JSONDecoder().decode(LiveWorkout.self, from: Data(contentsOf: url))
        guard value.isStructurallyValid else {
            throw InputError.invalid("The unfinished workout could not be restored. Its local file has been preserved.")
        }
        return value
    }
    func write(_ value: LiveWorkout?) throws {
        if let value { try JSONEncoder().encode(value).write(to: url, options: .atomic) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
