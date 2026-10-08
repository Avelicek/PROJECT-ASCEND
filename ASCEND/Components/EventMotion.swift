import SwiftUI

struct CompletionMotion: ViewModifier {
    let completed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    func body(content: Content) -> some View {
        content.scaleEffect(pulse ? 1.015 : 1)
            .shadow(color: SemanticStatus.excellent.tint.opacity(pulse ? 0.18 : 0), radius: pulse ? 14 : 0)
            .onChange(of: completed) { old, new in
                guard new && !old && !reduceMotion && !AppMotion.snapshotMode else { return }
                withAnimation(.easeOut(duration: 0.18)) { pulse = true }
            }
            .task(id: pulse) {
                guard pulse else { return }
                do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
                withAnimation(.easeInOut(duration: 0.25)) { pulse = false }
            }
    }
}
extension View { func completionMotion(_ completed: Bool) -> some View { modifier(CompletionMotion(completed: completed)) } }
