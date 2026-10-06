import SwiftUI
import UIKit

enum AppColor {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.063)
    static let surface = Color(red: 0.059, green: 0.071, blue: 0.11)
    static let elevated = Color(red: 0.086, green: 0.10, blue: 0.15)
    static let accent = Color(red: 0.48, green: 0.50, blue: 1)
    static let blue = Color(red: 0.38, green: 0.67, blue: 1)
    static let violet = Color(red: 0.64, green: 0.46, blue: 0.96)
    static let text = Color(red: 0.94, green: 0.95, blue: 1)
    static let muted = Color(red: 0.59, green: 0.64, blue: 0.74)
    static let positive = Color(red: 0.43, green: 0.83, blue: 0.73)
    static let warning = Color(red: 1, green: 0.69, blue: 0.45)
    static let separator = Color.white.opacity(0.075)
    static func rank(_ tier: RankTier) -> Color {
        switch tier {
        case .unranked: muted
        case .bronze: Color(red: 0.78, green: 0.55, blue: 0.35)
        case .silver: Color(red: 0.76, green: 0.81, blue: 0.90)
        case .gold: Color(red: 0.93, green: 0.78, blue: 0.42)
        case .platinum: blue
        case .diamond: Color(red: 0.57, green: 0.77, blue: 1)
        case .conqueror: violet
        }
    }
}
enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let page: CGFloat = 24
}
enum AppRadius { static let small: CGFloat = 12; static let card: CGFloat = 24; static let hero: CGFloat = 32 }
enum AppTypography {
    static let eyebrow: Font = .system(.caption2, design: .rounded, weight: .semibold)
    static let title: Font = .system(.title, design: .rounded, weight: .bold)
    static let metric: Font = .system(.largeTitle, design: .rounded, weight: .semibold)
    static let body: Font = .system(.subheadline, weight: .regular)
}
enum AppShadow { static let color = Color.black.opacity(0.24); static let radius: CGFloat = 20 }
enum AppAnimation {
    static let interaction = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let reveal = Animation.easeOut(duration: 0.65)
}
@MainActor enum AppHaptics {
    static func selection(enabled: Bool) { if enabled { UISelectionFeedbackGenerator().selectionChanged() } }
    static func success(enabled: Bool) { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func tap(enabled: Bool) { if enabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
}
struct PremiumPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : AppAnimation.interaction, value: configuration.isPressed)
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(AppTypography.eyebrow).tracking(2).foregroundStyle(AppColor.muted) }
}
struct FeatureHeader: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Eyebrow(text: eyebrow)
            Text(title).font(AppTypography.title).foregroundStyle(AppColor.text)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, AppSpacing.lg)
    }
}
struct FeatureBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppColor.background).foregroundStyle(AppColor.text).toolbar(.hidden, for: .navigationBar)
    }
}
extension View { func featureBackground() -> some View { modifier(FeatureBackground()) } }
