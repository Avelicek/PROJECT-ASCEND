import Foundation

struct PersonalTrainingStorage {
    let url: URL
    static func production() throws -> PersonalTrainingStorage {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ASCEND", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return .init(url: folder.appendingPathComponent("personal-training-v1.json"))
    }
    func read() throws -> PersonalTrainingState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let value = try JSONDecoder().decode(PersonalTrainingState.self, from: Data(contentsOf: url))
        guard value.version == 1, value.routines.count <= 100, value.routines.allSatisfy(\.isValid),
              (15...180).contains(value.profile.sessionMinutes) else {
            throw InputError.invalid("Personal training data could not be opened. The local file has been preserved.")
        }
        return value
    }
    func write(_ value: PersonalTrainingState) throws { try JSONEncoder().encode(value).write(to: url, options: .atomic) }
}
