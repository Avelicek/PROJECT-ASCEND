import SwiftUI
import UIKit

enum AppColor {
    static let background = Color(red: 0.016, green: 0.020, blue: 0.031)
    static let surface = Color(red: 0.042, green: 0.050, blue: 0.068)
    static let elevated = Color(red: 0.075, green: 0.086, blue: 0.112)
    static let accent = Color(red: 0.48, green: 0.50, blue: 1)
    static let blue = Color(red: 0.38, green: 0.67, blue: 1)
    static let violet = Color(red: 0.64, green: 0.46, blue: 0.96)
    static let text = Color(red: 0.88, green: 0.90, blue: 0.93)
    static let secondary = Color(red: 0.67, green: 0.71, blue: 0.77)
    static let muted = Color(red: 0.49, green: 0.55, blue: 0.64)
    static let elo = Color(red: 0.44, green: 0.72, blue: 0.93)
    static let cyan = Color(red: 0.65, green: 0.87, blue: 0.92)
    static let strength = Color(red: 0.61, green: 0.63, blue: 0.92)
    static let recovery = Color(red: 0.39, green: 0.76, blue: 0.80)
    static let nutrition = Color(red: 0.87, green: 0.66, blue: 0.39)
    static let sleep = Color(red: 0.65, green: 0.59, blue: 0.85)
    static let bodyweight = Color(red: 0.56, green: 0.73, blue: 0.83)
    static let gold = Color(red: 0.89, green: 0.76, blue: 0.48)
    static let negative = Color(red: 0.89, green: 0.53, blue: 0.52)
    static let eloGradient = LinearGradient(colors: [Color(red: 0.83, green: 0.89, blue: 0.95), elo, Color(red: 0.39, green: 0.47, blue: 0.61)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let goldGradient = LinearGradient(colors: [Color(red: 0.98, green: 0.88, blue: 0.66), gold], startPoint: .topLeading, endPoint: .bottomTrailing)
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
    static let page: CGFloat = 20
}
enum AppRadius { static let small: CGFloat = 12; static let card: CGFloat = 24; static let hero: CGFloat = 32 }
enum AppTypography {
    static let eyebrow: Font = .system(.caption2, design: .rounded, weight: .semibold)
    static let title: Font = .system(.title, design: .rounded, weight: .semibold)
    static let metric: Font = .system(.largeTitle, design: .rounded, weight: .semibold)
    static let body: Font = .system(.subheadline, weight: .regular)
}
enum AppShadow { static let color = Color.black.opacity(0.24); static let radius: CGFloat = 20 }
enum AppAnimation {
    static let micro = Animation.easeOut(duration: 0.16)
    static let interaction = Animation.spring(response: 0.28, dampingFraction: 0.88)
    static let reveal = Animation.easeOut(duration: 0.32)
    static let reward = Animation.spring(response: 0.75, dampingFraction: 0.86)
}
enum AppMotion {
    static var snapshotMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }
}
@MainActor enum AppHaptics {
    static func selection(enabled: Bool) { if enabled { UISelectionFeedbackGenerator().selectionChanged() } }
    static func success(enabled: Bool) { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func tap(enabled: Bool) { if enabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
    static func reward(enabled: Bool) { if enabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); UINotificationFeedbackGenerator().notificationOccurred(.success) } }
}
struct PremiumPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.micro, value: configuration.isPressed)
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(AppTypography.eyebrow).tracking(1.6).foregroundStyle(AppColor.muted) }
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
    var tint: Color = AppColor.elo
    func body(content: Content) -> some View {
        content.background {
            AppColor.background.overlay(alignment: .topLeading) {
                RadialGradient(colors: [tint.opacity(0.055), .clear], center: .topLeading, startRadius: 0, endRadius: 560)
                    .allowsHitTesting(false)
            }
        }.foregroundStyle(AppColor.secondary).toolbar(.hidden, for: .navigationBar)
    }
}
extension View { func featureBackground(tint: Color = AppColor.elo) -> some View { modifier(FeatureBackground(tint: tint)) } }
