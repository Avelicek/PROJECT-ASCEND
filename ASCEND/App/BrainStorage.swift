import Foundation

struct BrainStorage {
    let url: URL
    static func production() throws -> BrainStorage {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ASCEND", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return .init(url: folder.appendingPathComponent("personal-brain-v1.json"))
    }
    func read() throws -> BrainArchive? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let value = try JSONDecoder().decode(BrainArchive.self, from: Data(contentsOf: url))
        guard value.version == 1, value.history.count <= 180, value.preferences.count <= 300, Set(value.history.map(\.id)).count == value.history.count,
              value.history.allSatisfy({ $0.id.count <= 2000 && $0.focus.count <= 80 && $0.exerciseIDs.count <= 40 }) else {
            throw InputError.invalid("Brain history could not be opened. Its local file is preserved.")
        }
        return value
    }
    func write(_ value: BrainArchive) throws { try JSONEncoder().encode(value).write(to: url, options: .atomic) }
}
