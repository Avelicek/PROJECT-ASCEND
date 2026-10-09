import Foundation
import RealityKit
import UIKit

/// A single decoded, normalized template. Clones share meshes/material resources.
/// No renderer or camera survives dismissal; memory pressure evicts the template.
@MainActor final class AnatomyAssetCache: NSObject {
    static let shared = AnatomyAssetCache()
    private var template: Entity?
    private var loading: Task<Entity, Error>?
    private(set) var decodeCount = 0
    private(set) var lastCloneSeconds: Double = 0
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(memoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    @objc private func memoryWarning() { template = nil; loading?.cancel(); loading = nil }
    func clone() async throws -> Entity {
        let entity: Entity
        if let template { entity = template }
        else {
            if loading == nil {
                loading = Task {
                    guard let url = Bundle.main.url(forResource: "AscendMuscles", withExtension: "usdz", subdirectory: "Anatomy") else { throw OwnerSystemError.invalid }
                    let model = try await Entity(contentsOf: url)
                    let bounds = model.visualBounds(relativeTo: nil), scale: Float = 2 / max(0.01, bounds.extents.y)
                    model.scale *= SIMD3<Float>(repeating: scale); model.position = -bounds.center * scale
                    return model
                }
                decodeCount += 1
            }
            guard let loading else { throw OwnerSystemError.invalid }
            do { entity = try await loading.value; template = entity; self.loading = nil }
            catch { self.loading = nil; throw error }
        }
        let start = Date(); let copy = entity.clone(recursive: true); lastCloneSeconds = Date().timeIntervalSince(start)
        return copy
    }
    func preload() async { guard template == nil else { return }; _ = try? await clone() }
}
