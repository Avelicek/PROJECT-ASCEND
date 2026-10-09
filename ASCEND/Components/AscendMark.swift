import SwiftUI

/// Original three interrupted rising planes. Shared geometry with the vector/icon source.
struct AscendMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bands: [[CGPoint]] = [
            [.init(x: 0.16, y: 0.78), .init(x: 0.43, y: 0.24), .init(x: 0.53, y: 0.24), .init(x: 0.26, y: 0.78)],
            [.init(x: 0.36, y: 0.78), .init(x: 0.60, y: 0.30), .init(x: 0.69, y: 0.48), .init(x: 0.54, y: 0.78)],
            [.init(x: 0.64, y: 0.78), .init(x: 0.75, y: 0.56), .init(x: 0.86, y: 0.78)]
        ]
        for band in bands {
            for (index, point) in band.enumerated() {
                let position = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
                if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
            }
            path.closeSubpath()
        }
        return path
    }
}
struct CoachIdentity: View {
    var body: some View { AscendMark().fill(AppColor.text).frame(width: 32, height: 32).accessibilityHidden(true) }
}
