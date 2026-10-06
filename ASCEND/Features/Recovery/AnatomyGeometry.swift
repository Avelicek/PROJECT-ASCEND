import SwiftUI

struct AnatomyPatch: Identifiable {
    let id: String
    let region: BodyRegion
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path { AnatomyGeometry.smooth(points).applying(AnatomyGeometry.transform(in: rect)) }
}

// Geometry is a replaceable asset boundary; recovery and selection never depend on it.
protocol AnatomyGeometrySource {
    func patches(for mode: BodyViewMode) -> [AnatomyPatch]
    func silhouette(in rect: CGRect) -> Path
}

struct StylizedAnatomyAsset: AnatomyGeometrySource {
    func silhouette(in rect: CGRect) -> Path {
        let coords: [[CGFloat]] = [[89,46],[87,58],[73,64],[55,72],[45,85],[41,111],[34,139],[28,168],[24,189],[20,206],[22,220],[29,224],[35,212],[37,195],[44,178],[50,154],[58,133],[61,113],[69,140],[74,166],[70,187],[65,211],[64,245],[67,276],[74,303],[76,318],[73,347],[77,377],[79,409],[75,431],[66,443],[67,449],[88,448],[93,439],[91,414],[92,381],[96,350],[94,322],[95,300],[98,267],[100,240]]
        let left = coords.map { CGPoint(x: $0[0], y: $0[1]) }
        let right = left.dropLast().reversed().map { CGPoint(x: 200 - $0.x, y: $0.y) }
        var path = AnatomyGeometry.smooth(left + right)
        path.addEllipse(in: CGRect(x: 83, y: 5, width: 34, height: 44))
        return path.applying(AnatomyGeometry.transform(in: rect))
    }
    func patches(for mode: BodyViewMode) -> [AnatomyPatch] {
        var result: [AnatomyPatch] = []
        func pair(_ name: String, _ region: BodyRegion, _ coords: [[CGFloat]]) {
            let left = coords.map { CGPoint(x: $0[0], y: $0[1]) }
            result.append(AnatomyPatch(id: name + ".left", region: region, points: left))
            result.append(AnatomyPatch(id: name + ".right", region: region, points: left.map { CGPoint(x: 200 - $0.x, y: $0.y) }))
        }
        if mode == .front {
            pair("clavicular", .chest, [[67,75],[81,72],[97,74],[97,86],[78,91],[66,87]])
            pair("pectoral", .chest, [[66,90],[80,94],[97,89],[96,107],[83,117],[70,111],[63,101]])
            pair("anterior.deltoid", .shoulders, [[58,73],[65,75],[62,91],[57,106],[47,101],[47,86]])
            pair("lateral.deltoid", .shoulders, [[45,91],[49,105],[57,110],[51,118],[43,112]])
            pair("biceps", .arms, [[46,116],[56,116],[52,136],[44,151],[38,145],[39,131]])
            pair("brachialis", .arms, [[57,121],[58,137],[49,153],[46,148],[53,131]])
            pair("forearm.flexors", .arms, [[38,154],[44,156],[41,173],[32,192],[27,191],[30,170]])
            pair("forearm.extensors", .arms, [[45,155],[48,158],[42,178],[35,195],[33,187]])
            for row in 0..<4 {
                let y = CGFloat(121 + row * 17)
                pair("rectus.\(row)", .core, [[86,y],[97,y-2],[97,y+10],[88,y+12],[84,y+7]])
            }
            pair("obliques", .core, [[73,128],[81,134],[82,172],[96,191],[78,182],[73,156]])
            for row in 0..<3 {
                let y = CGFloat(117 + row * 8)
                pair("serratus.\(row)", .core, [[68,y],[78,y+3],[77,y+9],[70,y+6]])
            }
            pair("vastus.lateral", .legs, [[69,218],[79,219],[81,251],[80,278],[76,298],[70,282],[67,252]])
            pair("rectus.femoris", .legs, [[82,216],[91,220],[92,243],[87,277],[82,292],[81,268]])
            pair("adductor", .legs, [[93,213],[98,236],[95,268],[89,287],[87,274],[91,240]])
            pair("vastus.medial", .legs, [[86,283],[93,278],[91,302],[85,310],[81,302]])
            pair("tibialis", .calves, [[79,327],[84,328],[87,362],[85,402],[81,402],[79,372]])
            pair("lateral.calf", .calves, [[88,328],[93,330],[93,350],[89,378],[87,370]])
        } else {
            pair("upper.trapezius", .back, [[89,54],[97,56],[97,86],[83,80],[68,73],[77,64]])
            pair("middle.trapezius", .back, [[74,79],[89,86],[97,88],[97,115],[85,105]])
            pair("infraspinatus", .back, [[65,81],[74,84],[83,108],[74,115],[62,99]])
            pair("teres", .back, [[63,104],[74,119],[80,121],[73,128],[63,117]])
            pair("latissimus", .back, [[67,124],[81,121],[96,116],[90,146],[79,166],[74,169],[70,144]])
            pair("erectors", .back, [[93,127],[97,119],[97,187],[85,181],[82,167],[88,148]])
            pair("posterior.deltoid", .shoulders, [[57,73],[66,78],[61,94],[56,111],[45,103],[46,87]])
            pair("triceps.long", .arms, [[47,115],[58,112],[55,130],[45,152],[39,145],[40,131]])
            pair("triceps.lateral", .arms, [[43,117],[47,120],[43,140],[38,144],[37,139]])
            pair("forearm.back", .arms, [[37,154],[45,158],[42,177],[33,194],[27,191],[29,173]])
            pair("forearm.ulnar", .arms, [[46,161],[48,161],[42,182],[36,195],[34,187]])
            pair("glute.medial", .glutes, [[75,187],[86,190],[96,190],[95,201],[76,205],[68,202]])
            pair("glute.maximus", .glutes, [[69,206],[81,207],[97,202],[96,219],[88,235],[75,236],[67,224]])
            pair("biceps.femoris", .legs, [[69,242],[78,243],[81,264],[80,290],[77,308],[71,291],[67,265]])
            pair("semitendinosus", .legs, [[83,239],[94,239],[92,272],[85,305],[82,295],[84,268]])
            pair("medial.calf", .calves, [[85,327],[92,326],[94,342],[91,365],[85,375],[82,359]])
            pair("lateral.calf.back", .calves, [[78,329],[82,329],[81,353],[83,367],[79,374],[75,356]])
            pair("soleus", .calves, [[80,381],[87,382],[87,409],[82,418]])
        }
        return result
    }
}

enum AnatomyGeometry {
    // Normalized 200 × 460 artboard shared by rendering and touch hit testing.
    static func transform(in rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(a: rect.width / 200, b: 0, c: 0, d: rect.height / 460, tx: rect.minX, ty: rect.minY)
    }
    static func smooth(_ points: [CGPoint]) -> Path {
        guard points.count >= 3 else { return Path() }
        var path = Path()
        path.move(to: points[0])
        for index in points.indices {
            let a = points[(index + points.count - 1) % points.count]
            let b = points[index]
            let c = points[(index + 1) % points.count]
            let d = points[(index + 2) % points.count]
            path.addCurve(to: c,
                control1: CGPoint(x: b.x + (c.x - a.x) / 6, y: b.y + (c.y - a.y) / 6),
                control2: CGPoint(x: c.x - (d.x - b.x) / 6, y: c.y - (d.y - b.y) / 6))
        }
        path.closeSubpath()
        return path
    }
}
