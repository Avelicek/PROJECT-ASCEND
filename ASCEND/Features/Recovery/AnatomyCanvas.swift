import SwiftUI

struct AnatomyCanvas: View {
    let mode: BodyViewMode
    let selected: BodyRegion
    let regions: [RegionVisualization]
    var asset: any AnatomyGeometrySource = StylizedAnatomyAsset()
    let onSelect: (BodyRegion) -> Void
    var body: some View {
        GeometryReader { proxy in
            let artboard = artboard(in: proxy.size)
            Canvas { context, size in
                drawStage(context: &context, size: size)
                let silhouette = asset.silhouette(in: artboard)
                context.fill(silhouette, with: .linearGradient(Gradient(colors: [Color(red: 0.22, green: 0.27, blue: 0.35), AppColor.elevated, Color(red: 0.08, green: 0.11, blue: 0.16)]),
                    startPoint: CGPoint(x: artboard.minX, y: 0), endPoint: CGPoint(x: artboard.maxX, y: size.height)))
                context.stroke(silhouette, with: .color(AppColor.blue.opacity(0.25)), lineWidth: 0.8)
                for patch in asset.patches(for: mode) {
                    if let state = regions.first(where: { $0.region == patch.region }) { draw(patch, state: state, in: artboard, context: context) }
                }
                var axis = Path()
                axis.move(to: CGPoint(x: artboard.midX, y: artboard.minY + artboard.height * 0.13))
                axis.addLine(to: CGPoint(x: artboard.midX, y: artboard.minY + artboard.height * 0.41))
                context.stroke(axis, with: .color(.white.opacity(mode == .back ? 0.24 : 0.1)), style: StrokeStyle(lineWidth: 0.8, dash: mode == .back ? [2, 3] : []))
                for x in [CGFloat(84), CGFloat(116)] {
                    let knee = CGRect(x: artboard.minX + (x - 5) / 200 * artboard.width,
                        y: artboard.minY + 312 / 460 * artboard.height, width: artboard.width * 0.05, height: artboard.height * 0.022)
                    context.fill(Path(ellipseIn: knee), with: .color(.white.opacity(0.09)))
                }
            }.gesture(SpatialTapGesture().onEnded { event in
                if let patch = asset.patches(for: mode).last(where: { $0.path(in: artboard).contains(event.location) }) { onSelect(patch.region) }
            })
        }.accessibilityHidden(true)
    }
    private func artboard(in size: CGSize) -> CGRect {
        let height = size.height - 16
        let width = min(size.width - 20, height * 200 / 460)
        return CGRect(x: (size.width - width) / 2, y: 4, width: width, height: height)
    }
    private func drawStage(context: inout GraphicsContext, size: CGSize) {
        let stage = Path(ellipseIn: CGRect(x: size.width * 0.1, y: 12, width: size.width * 0.8, height: size.height - 24))
        context.fill(stage, with: .radialGradient(Gradient(colors: [AppColor.blue.opacity(0.11), .clear]),
            center: CGPoint(x: size.width / 2, y: size.height * 0.4), startRadius: 0, endRadius: size.height * 0.52))
        var grid = Path()
        for row in 1..<10 {
            let y = CGFloat(row) * size.height / 10
            grid.move(to: CGPoint(x: 14, y: y)); grid.addLine(to: CGPoint(x: size.width - 14, y: y))
        }
        context.stroke(grid, with: .color(AppColor.blue.opacity(0.06)), lineWidth: 0.5)
        let floor = Path(ellipseIn: CGRect(x: size.width * 0.18, y: size.height - 14, width: size.width * 0.64, height: 10))
        context.fill(floor, with: .radialGradient(Gradient(colors: [AppColor.blue.opacity(0.18), .clear]),
            center: CGPoint(x: size.width / 2, y: size.height - 9), startRadius: 0, endRadius: size.width * 0.35))
    }
    private func draw(_ patch: AnatomyPatch, state: RegionVisualization, in rect: CGRect, context: GraphicsContext) {
        let path = patch.path(in: rect)
        let bounds = path.boundingRect
        let active = patch.region == selected
        let tint = state.phase.tint
        let strength: Double = state.phase == .unknown ? 0.26 : active ? 0.88 : 0.5
        var layer = context
        if active {
            layer.addFilter(.shadow(color: tint.opacity(0.4), radius: 6))
            layer.stroke(path, with: .color(tint.opacity(0.65)), lineWidth: 1.4)
        }
        layer.fill(path, with: .linearGradient(Gradient(colors: [tint.opacity(strength), tint.opacity(strength * 0.48), AppColor.background.opacity(0.8)]),
            startPoint: CGPoint(x: bounds.minX, y: bounds.minY), endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
        var light = context
        light.clip(to: path)
        light.fill(path, with: .radialGradient(Gradient(colors: [.white.opacity(active ? 0.33 : 0.19), .clear]),
            center: CGPoint(x: bounds.minX + bounds.width * 0.34, y: bounds.minY + bounds.height * 0.2), startRadius: 0, endRadius: max(bounds.width, bounds.height) * 0.78))
        var fibres = Path()
        for index in 1...5 {
            let x = bounds.minX + bounds.width * CGFloat(index) / 6
            fibres.move(to: CGPoint(x: x, y: bounds.minY))
            fibres.addQuadCurve(to: CGPoint(x: x - bounds.width * 0.15, y: bounds.maxY), control: CGPoint(x: x + bounds.width * 0.22, y: bounds.midY))
        }
        light.stroke(fibres, with: .color(.white.opacity(active ? 0.17 : 0.08)), lineWidth: 0.45)
        context.stroke(path, with: .color(active ? tint.opacity(0.95) : .white.opacity(0.12)), lineWidth: active ? 1.15 : 0.65)
    }
}
