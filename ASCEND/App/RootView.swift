import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case dashboard, workout, recovery, progress, profile
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self { case .dashboard: "square.grid.2x2"; case .workout: "dumbbell"; case .recovery: "figure.stand"; case .progress: "chart.xyaxis.line"; case .profile: "person.crop.circle" }
    }
}
enum LogDestination: String, Identifiable { case weight, nutrition, sleep, workout, objectives; var id: String { rawValue } }

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var destination = AppDestination.dashboard
    @Namespace private var tabHighlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        @Bindable var store = store
        TabView(selection: $destination) {
            NavigationStack { DashboardView() }.tag(AppDestination.dashboard).toolbar(.hidden, for: .tabBar)
            NavigationStack { WorkoutView() }.tag(AppDestination.workout).toolbar(.hidden, for: .tabBar)
            NavigationStack { RecoveryView() }.tag(AppDestination.recovery).toolbar(.hidden, for: .tabBar)
            NavigationStack { ProgressScreen() }.tag(AppDestination.progress).toolbar(.hidden, for: .tabBar)
            NavigationStack { ProfileView() }.tag(AppDestination.profile).toolbar(.hidden, for: .tabBar)
        }.safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            .onChange(of: store.navigationRequest) { _, request in if let request { destination = request; store.navigationRequest = nil } }
            .background(AppColor.background)
            .fullScreenCover(isPresented: $store.liveWorkoutPresented) {
                NavigationStack { LiveWorkoutView().environment(store) }.preferredColorScheme(.dark).tint(AppColor.strength)
            }
            .sheet(item: $store.presentedSheet) { route in
                NavigationStack {
                    switch route {
                    case .weight: WeightEditor()
                    case .nutrition: NutritionEditor()
                    case .sleep: SleepEditor()
                    case .workout: WorkoutEditor()
                    case .objectives: ObjectiveManager()
                    }
                }.environment(store).preferredColorScheme(.dark).tint(AppColor.accent)
            }
            .alert("Couldn't save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "Please try again.") }
            .task {
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                    store.refreshSafely()
                }
            }
    }
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppDestination.allCases) { item in
                Button {
                    AppHaptics.selection(enabled: store.settings.hapticsEnabled)
                    withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction) { destination = item }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(.body, weight: destination == item ? .semibold : .regular))
                            .frame(width: 44, height: 27)
                            .background {
                                if destination == item {
                                    Capsule().fill(AppColor.accent.opacity(0.20)).matchedGeometryEffect(id: "selectedTab", in: tabHighlight)
                                        .overlay { Capsule().strokeBorder(AppColor.accent.opacity(0.25)) }
                                }
                            }
                        Text(item.title).font(.system(.caption2, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                    }.foregroundStyle(destination == item ? AppColor.text : AppColor.muted)
                        .frame(maxWidth: .infinity, minHeight: 56).contentShape(Rectangle())
                }.buttonStyle(PremiumPressStyle()).accessibilityLabel(item.title)
                    .accessibilityIdentifier("tab.\(item.rawValue)")
                    .accessibilityValue(destination == item ? "Selected" : "")
                    .accessibilityAddTraits(destination == item ? .isSelected : [])
            }
        }.padding(.horizontal, AppSpacing.sm).padding(.top, 10).padding(.bottom, 4)
            .background(.ultraThinMaterial).overlay(alignment: .top) { Rectangle().fill(AppColor.separator).frame(height: 1) }
    }
}

#Preview("ASCEND · demo") {
    if let store = try? PreviewData.makeStore() { RootView().environment(store).preferredColorScheme(.dark) }
}
#Preview("ASCEND · first launch") {
    if let container = try? PersistenceController.makeContainer(inMemory: true), let store = try? AppStore(container: container) {
        RootView().environment(store).preferredColorScheme(.dark)
    }
}
