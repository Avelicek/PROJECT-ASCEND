import Foundation

struct OwnerSystemStorage {
    let url: URL
    func read() throws -> OwnerSystem? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let state = try JSONDecoder().decode(OwnerSystem.self, from: Data(contentsOf: url))
        try state.validate(); return state
    }
    func write(_ state: OwnerSystem) throws { try state.validate(); try JSONEncoder().encode(state).write(to: url, options: .atomic) }
}

// Commit point for restore/reset. Only validated, fully saved generations can be selected.
enum OwnerStoreLocation {
    static func root() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ASCEND", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); return root
    }
    static func selectedFolder() throws -> URL {
        let root = try root(), pointer = root.appendingPathComponent("active-generation.json")
        guard FileManager.default.fileExists(atPath: pointer.path) else { return root }
        let name = try JSONDecoder().decode(String.self, from: Data(contentsOf: pointer))
        guard UUID(uuidString: name) != nil else { throw OwnerSystemError.invalid }
        let folder = root.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("Ascend.store").path) else { throw OwnerSystemError.invalid }
        return folder
    }
    static func cleanRetiredData() throws {
        let selected = try selectedFolder(), root = try root()
        guard selected != root else { return }
        let manifest = selected.appendingPathComponent("retired-files.json")
        if FileManager.default.fileExists(atPath: manifest.path) {
            let paths = try JSONDecoder().decode([String].self, from: Data(contentsOf: manifest))
            let support = root.deletingLastPathComponent().standardizedFileURL.path + "/"
            for path in paths {
                let url = URL(fileURLWithPath: path).standardizedFileURL
                guard url.path.hasPrefix(support), !url.path.hasPrefix(selected.path + "/"),
                      ["owner-system-v1.json", "personal-training-v1.json", "personal-brain-v1.json", "active-workout-v1.json"].contains(url.lastPathComponent) || url.lastPathComponent.contains(".store") else { throw OwnerSystemError.invalid }
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            try FileManager.default.removeItem(at: manifest)
        }
        for item in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where item != selected && UUID(uuidString: item.lastPathComponent) != nil {
            guard item.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else { throw OwnerSystemError.invalid }
            try FileManager.default.removeItem(at: item)
        }
    }
    static func stagingFolder() throws -> URL {
        let folder = try root().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); return folder
    }
    static func commit(_ folder: URL) throws {
        guard UUID(uuidString: folder.lastPathComponent) != nil, folder.deletingLastPathComponent().standardizedFileURL == (try root()).standardizedFileURL else { throw OwnerSystemError.invalid }
        try JSONEncoder().encode(folder.lastPathComponent).write(to: try root().appendingPathComponent("active-generation.json"), options: .atomic)
    }
}
