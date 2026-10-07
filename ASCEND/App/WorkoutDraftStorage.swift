import Foundation

struct WorkoutDraftStorage {
    let url: URL
    static func production() throws -> WorkoutDraftStorage {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ASCEND", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return WorkoutDraftStorage(url: folder.appendingPathComponent("active-workout-v1.json"))
    }
    func read() throws -> LiveWorkout? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let value = try JSONDecoder().decode(LiveWorkout.self, from: Data(contentsOf: url))
        guard value.version == 1, value.exercises.count <= 40, value.exercises.allSatisfy({ $0.sets.count <= 40 }) else {
            throw InputError.invalid("The unfinished workout could not be restored. Its local file has been preserved.")
        }
        return value
    }
    func write(_ value: LiveWorkout?) throws {
        if let value { try JSONEncoder().encode(value).write(to: url, options: .atomic) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
