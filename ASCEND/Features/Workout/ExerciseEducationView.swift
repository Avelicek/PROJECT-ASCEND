import SwiftUI

struct ExerciseEducationView: View {
    @Environment(AppStore.self) private var store
    let exerciseID: String
    @State private var anatomy = false
    var body: some View {
        ScrollView {
            if let exercise = store.trainingMetadata(exerciseID) {
                let guide = ExerciseEducation.guide(exercise)
                VStack(alignment: .leading, spacing: 20) {
                    FeatureHeader(eyebrow: "MOVEMENT GUIDE", title: exercise.name)
                    MuscleActivationPreview(contributions: exercise.muscles, pattern: guide.visual)
                    Text(exercise.required.map(\.title).sorted().joined(separator: " · ")).font(.subheadline).foregroundStyle(AppColor.secondary)
                    Eyebrow(text: "HOW TO DO IT")
                    ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, text in Text("\(index + 1). \(text)").font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                    DisclosureGroup("Form cues") { ForEach(guide.cues, id: \.self) { Text($0).font(.caption).foregroundStyle(AppColor.secondary).padding(.top, 8) } }.font(.subheadline)
                    Button(anatomy ? "Hide anatomy" : "Explore muscle contributions in 3D", systemImage: "figure.stand") { anatomy.toggle() }.frame(minHeight: 44)
                    if anatomy { ExerciseAnatomyPreview(contributions: exercise.muscles) }
                    ForEach(exercise.muscles.sorted { $0.fraction > $1.fraction }, id: \.muscle) { part in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(part.muscle.title); Spacer(); Text(part.fraction >= 0.35 ? "Primary" : part.fraction >= 0.15 ? "Secondary" : "Stabilizer").foregroundStyle(AppColor.muted) }.font(.caption)
                            LinearProgress(progress: part.fraction, tint: AppColor.strength)
                        }
                    }
                    Text("Contribution intensity is a training model, not measured muscle activation.").font(.caption).foregroundStyle(AppColor.muted)
                }.padding(20)
            }
        }.featureBackground(tint: AppColor.strength).toolbar(.visible, for: .navigationBar).navigationTitle("Exercise guide").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.exerciseguide")
    }
}

struct WorkoutFocusMap: View {
    @Environment(AppStore.self) private var store
    let exerciseIDs: [String]
    var body: some View {
        let parts = exerciseIDs.compactMap { store.trainingMetadata($0) }.flatMap(\.muscles)
        let groups = Dictionary(grouping: parts) { $0.muscle.group }.map { ($0.key, $0.value.reduce(0) { $0 + $1.fraction }) }.sorted { $0.1 > $1.1 }
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "TODAY'S MUSCLE FOCUS")
            ForEach(groups.prefix(5), id: \.0) { name, weight in
                HStack { Text(name).font(.caption).frame(width: 80, alignment: .leading); LinearProgress(progress: weight / max(1, groups.first?.1 ?? 1), tint: AppColor.strength) }
            }
        }
    }
}

struct MuscleActivationPreview: View {
    let contributions: [MuscleContribution]
    let pattern: MovementPattern
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || phase != .active || AppMotion.snapshotMode)) { time in
            let progress = reduceMotion || AppMotion.snapshotMode ? 0.5 : (sin(time.date.timeIntervalSinceReferenceDate * 2) + 1) / 2
            MovementIllustration(pattern: pattern, progress: progress, contributions: contributions).frame(height: 180)
        }.background(AppColor.surface, in: RoundedRectangle(cornerRadius: 18)).accessibilityElement(children: .ignore)
            .accessibilityLabel("Loop illustrating \(pattern.title). Primary and supporting muscles: \(contributions.sorted { $0.fraction > $1.fraction }.map { $0.muscle.title }.joined(separator: ", ")).")
    }
}

private struct MovementIllustration: View {
    let pattern: MovementPattern
    let progress: Double
    let contributions: [MuscleContribution]
    var body: some View {
        Canvas { context, size in
            func point(_ x: Double, _ y: Double) -> CGPoint { .init(x: x * size.width, y: y * size.height) }
            let p = progress
            var head = point(0.5, 0.18), shoulder = point(0.5, 0.3), hip = point(0.5, 0.58)
            var knee = point(0.53, 0.74), foot = point(0.53, 0.91), elbow = point(0.63, 0.43), hand = point(0.62, 0.58)
            switch pattern {
            case .horizontalPush:
                head = point(0.73, 0.29 + p * 0.20); shoulder = point(0.65, 0.35 + p * 0.20); hip = point(0.39, 0.5 + p * 0.10)
                knee = point(0.24, 0.65); foot = point(0.14, 0.81); elbow = point(0.73, 0.62); hand = point(0.65, 0.81)
            case .squat, .lunge, .kneeExtension:
                head = point(0.5, 0.18 + p * 0.2); shoulder = point(0.5, 0.3 + p * 0.2); hip = point(0.43 - p * 0.1, 0.58 + p * 0.12); knee = point(0.58, 0.74); elbow = point(0.62, 0.46 + p * 0.1); hand = point(0.6, 0.33 + p * 0.2)
            case .hinge:
                head = point(0.5 + p * 0.22, 0.18 + p * 0.2); shoulder = point(0.5 + p * 0.16, 0.3 + p * 0.2); hip = point(0.45 - p * 0.08, 0.58); elbow = point(0.55 + p * 0.1, 0.55); hand = point(0.58 + p * 0.08, 0.76)
            case .verticalPush, .verticalPull: elbow = point(0.66, 0.35 - p * 0.18); hand = point(0.63, 0.20 - p * 0.15)
            case .horizontalPull: elbow = point(0.65 - p * 0.05, 0.48); hand = point(0.8 - p * 0.20, 0.40)
            case .elbowFlexion: hand = point(0.62, 0.59 - p * 0.30)
            case .elbowExtension: hand = point(0.67, 0.4 + p * 0.24)
            case .shoulderIsolation: elbow = point(0.64 + p * 0.10, 0.45 - p * 0.15); hand = point(0.66 + p * 0.22, 0.59 - p * 0.29)
            case .coreStability, .carry: head = point(0.75, 0.42); shoulder = point(0.68, 0.49); hip = point(0.4, 0.56); knee = point(0.26, 0.64); foot = point(0.16, 0.75); elbow = point(0.65, 0.74); hand = point(0.80, 0.74)
            case .coreFlexion: head = point(0.73 - p * 0.15, 0.6 - p * 0.2); shoulder = point(0.65 - p * 0.1, 0.68 - p * 0.16); hip = point(0.42, 0.75); knee = point(0.33, 0.5); foot = point(0.2, 0.82); elbow = point(0.73 - p * 0.1, 0.73 - p * 0.18); hand = point(0.74 - p * 0.15, 0.56 - p * 0.2)
            case .calf: head.y -= p * 10; shoulder.y -= p * 10; hip.y -= p * 10
            case .locomotion: knee = point(0.5 + (p - 0.5) * 0.3, 0.72); foot = point(0.5 + (p - 0.5) * 0.5, 0.90); elbow = point(0.60, 0.43); hand = point(0.60 + (p - 0.5) * 0.2, 0.58)
            case .kneeFlexion: foot = point(0.5 - p * 0.25, 0.91 - p * 0.2)
            case .hipAbduction: foot = point(0.53 + p * 0.2, 0.91)
            }
            func line(_ points: [CGPoint], color: Color, width: CGFloat) {
                var path = Path(); if let first = points.first { path.move(to: first) }; for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(color), style: .init(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            line([point(0.10, 0.93), point(0.90, 0.93)], color: AppColor.separator, width: 1)
            line([shoulder, hip, knee, foot], color: AppColor.secondary, width: 8)
            line([shoulder, elbow, hand], color: AppColor.secondary, width: 7)
            let highest = contributions.max { $0.fraction < $1.fraction }?.fraction ?? 1
            for part in contributions {
                let intensity = part.fraction / max(0.01, highest) * (0.55 + p * 0.45)
                let group = part.muscle.group
                let points: [CGPoint] = ["Chest", "Back", "Core"].contains(group) ? [shoulder, hip] : ["Arms", "Shoulders"].contains(group) ? [shoulder, elbow] : ["Legs", "Glutes"].contains(group) ? [hip, knee] : [knee, foot]
                line(points, color: AppColor.strength.opacity(intensity), width: 11)
            }
            context.fill(Path(ellipseIn: CGRect(x: head.x - 10, y: head.y - 10, width: 20, height: 20)), with: .color(AppColor.secondary))
        }
    }
}

struct ExerciseAnatomyPreview: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let contributions: [MuscleContribution]
    @State private var ready = false
    @State private var failed = false
    @State private var reset = 0
    var body: some View {
        VStack {
            if phase == .active && !failed {
                TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion || AppMotion.snapshotMode)) { time in
                    NativeAnatomyView(report: store.readiness, metric: .load, selected: .chest, back: false, cameraReset: reset, cameraSide: false, selectedMesh: nil,
                        onSelect: { _, _ in }, onReady: { ready = true }, onFailure: { failed = true }, activation: contributions,
                        activationPhase: reduceMotion || AppMotion.snapshotMode ? 1 : 0.65 + 0.35 * sin(time.date.timeIntervalSinceReferenceDate * 2))
                }.frame(height: 320)
                if !ready { ProgressView("Preparing anatomy") }
                Button("Reset camera") { reset += 1 }.frame(minHeight: 44)
            } else { Text("Muscle contributions remain available in the list.").font(.caption) }
        }
    }
}
