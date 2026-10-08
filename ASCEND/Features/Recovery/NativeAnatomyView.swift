import SwiftUI
import RealityKit
import UIKit
import simd

// Presentation only: mesh names never enter fitness engines or persisted training data.
struct NativeAnatomyView: UIViewRepresentable {
    let report: ReadinessReport
    let metric: AnatomyMetricMode
    let selected: BodyRegion
    let back: Bool
    let cameraReset: Int
    let cameraSide: Bool
    let selectedMesh: String?
    let onSelect: (BodyRegion, String) -> Void
    let onReady: () -> Void
    let onFailure: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.backgroundColor = UIColor(AppColor.background)
        view.environment.background = .color(UIColor(AppColor.background))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain, .disableGroundingShadows]
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Z-Anatomy muscle model. Drag to orbit, pinch to zoom, tap a muscle to select. The region buttons below offer the same information."
        view.accessibilityIdentifier = "anatomy.native"
        context.coordinator.install(view)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) { context.coordinator.update(self) }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.dispose(); view.scene.anchors.removeAll(); view.session.pause() }
    @MainActor final class Coordinator: NSObject {
        private var parent: NativeAnatomyView
        private weak var view: ARView?
        private let anchor = AnchorEntity(world: .zero)
        private let orbit = Entity()
        private let camera = PerspectiveCamera()
        private var models: [ModelEntity] = []
        private var loadTask: Task<Void, Never>?
        private var yaw: Float = 0
        private var pitch: Float = 0
        private var zoom: Float = 3.5
        private var reset = 0
        private var materialKeys: [ObjectIdentifier: String] = [:]
        init(_ parent: NativeAnatomyView) { self.parent = parent; super.init() }
        func install(_ view: ARView) {
            self.view = view; camera.camera.fieldOfViewInDegrees = 42; camera.position = [0, 0, zoom]
            anchor.addChild(camera); anchor.addChild(orbit); view.scene.anchors.append(anchor)
            let key = DirectionalLight(); key.light.intensity = 1700; key.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0]); anchor.addChild(key)
            let fill = DirectionalLight(); fill.light.intensity = 800; fill.orientation = simd_quatf(angle: .pi / 3, axis: [0, 1, 0]); anchor.addChild(fill)
            view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
            view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
            loadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    guard let url = Bundle.main.url(forResource: "AscendMuscles", withExtension: "usdz", subdirectory: "Anatomy") else { throw OwnerSystemError.invalid }
                    let entity = try await Entity(contentsOf: url)
                    guard !Task.isCancelled, self.view != nil else { return }
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let scale: Float = 2 / max(0.01, bounds.extents.y)
                    let center = bounds.center
                    entity.scale *= SIMD3<Float>(repeating: scale); entity.position = -center * scale
                    self.orbit.addChild(entity)
                    self.collect(entity)
                    guard !self.models.isEmpty else { throw OwnerSystemError.invalid }
                    self.update(self.parent)
                    self.view?.accessibilityValue = "Ready"
                    self.parent.onReady()

                    // Collision generation across hundreds of meshes is intentionally incremental so
                    // RealityKit never blocks the main UI/accessibility loop for tens of seconds.
                    // Screenshot mode does not need hit-testing at all.
                    if !AppMotion.nativeAnatomyCapture {
                        for model in self.models where AnatomyMeshMapping.muscles[self.meshKey(model)] != nil {
                            guard !Task.isCancelled, self.view != nil else { return }
                            model.generateCollisionShapes(recursive: false)
                            await Task.yield()
                        }
                    }
                } catch { if !Task.isCancelled { self.parent.onFailure() } }
            }
        }
        private func collect(_ entity: Entity) { if let model = entity as? ModelEntity { models.append(model) }; for child in entity.children { collect(child) } }
        private func meshKey(_ entity: Entity) -> String {
            var candidate: Entity? = entity
            while let item = candidate { if AnatomyMeshMapping.sourceNames[item.name] != nil { return item.name }; candidate = item.parent }
            return entity.name
        }
        func update(_ parent: NativeAnatomyView) {
            let viewChanged = self.parent.back != parent.back || self.parent.cameraSide != parent.cameraSide
            self.parent = parent
            if reset != parent.cameraReset || viewChanged { yaw = parent.cameraSide ? .pi / 2 : parent.back ? .pi : 0; pitch = 0; zoom = 3.5; reset = parent.cameraReset }
            orient()
            let maximumLoad = max(1, parent.report.muscles.map(\.load).max() ?? 1)
            for model in models {
                let keys = AnatomyMeshMapping.muscles[meshKey(model)] ?? []
                let observed = parent.report.muscles.filter { keys.contains($0.muscle) && $0.lastTrainedAt != nil }
                let status: SemanticStatus
                switch parent.metric {
                case .recovery: status = SemanticStatus.recovery(observed.map(\.recoveryPercent).min())
                case .fatigue: status = SemanticStatus.fatigue(observed.map(\.fatigue).max())
                case .load: status = observed.isEmpty ? .unknown : (observed.map(\.load).max() ?? 0) / maximumLoad >= 0.7 ? .watch : .good
                }
                let selected = parent.selectedMesh == meshKey(model)
                let materialKey = status.rawValue + (selected ? ":selected" : ":normal")
                let identity = ObjectIdentifier(model)
                if materialKeys[identity] == materialKey { continue }
                materialKeys[identity] = materialKey
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(status.tint).getRed(&r, green: &g, blue: &b, alpha: &a)
                let factor: CGFloat = selected ? 0.7 : 0.30
                let color = UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: 1)
                var material = SimpleMaterial(color: color, roughness: selected ? 0.45 : 0.72, isMetallic: false)
                // Restrained status surfaces, with neutral unobserved anatomy.
                if status == .unknown { material = SimpleMaterial(color: UIColor(red: 0.16, green: 0.19, blue: 0.24, alpha: 1), roughness: 0.75, isMetallic: false) }
                model.model?.materials = [material]
            }
        }
        private func orient() { orbit.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0]); camera.position = [0, 0, zoom] }
        @objc private func pan(_ gesture: UIPanGestureRecognizer) { let movement = gesture.translation(in: view); yaw += Float(movement.x) * 0.008; pitch = min(0.6, max(-0.6, pitch + Float(movement.y) * 0.005)); gesture.setTranslation(.zero, in: view); orient() }
        @objc private func pinch(_ gesture: UIPinchGestureRecognizer) { zoom = min(5.5, max(2, zoom / Float(gesture.scale))); gesture.scale = 1; orient() }
        @objc private func tap(_ gesture: UITapGestureRecognizer) {
            guard let view, let entity = view.entity(at: gesture.location(in: view)), let muscles = AnatomyMeshMapping.muscles[meshKey(entity)], let muscle = muscles.first,
                  let region = BodyRegion(rawValue: muscle.group) else { return }
            parent.onSelect(region, meshKey(entity))
        }
        func dispose() { loadTask?.cancel(); loadTask = nil; models.removeAll(); materialKeys.removeAll(); Array(orbit.children).forEach { $0.removeFromParent() }; view = nil }
    }
}
