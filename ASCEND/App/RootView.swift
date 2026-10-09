import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case dashboard, workout, recovery, progress, profile
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self { case .dashboard: "square.grid.2x2"; case .workout: "dumbbell"; case .recovery: "figure.stand"; case .progress: "chart.xyaxis.line"; case .profile: "person.crop.circle" }
    }
}
enum LogDestination: String, Identifiable { case weight, nutrition, sleep, workout, objectives, checkIn, ask, weekly; var id: String { rawValue } }

private struct DayWakeKey: Hashable { let active: Bool; let day: String }

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var destination: AppDestination
    @Namespace private var tabHighlight
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init() {
        var initial = AppDestination.dashboard
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--demo"), arguments.contains("--ui-testing"), arguments.contains(where: { ["--capture-library", "--capture-routine", "--capture-history", "--capture-plan", "--capture-quick", "--capture-guide"].contains($0) }) { initial = .workout }
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") && ProcessInfo.processInfo.arguments.contains("--capture-data") { initial = .profile }
        #endif
        if AppMotion.nativeAnatomyCapture { initial = .recovery }
        _destination = State(initialValue: initial)
    }
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
                    case .checkIn: MorningCheckInView()
                    case .ask: AskAscendView()
                    case .weekly: WeeklyRecapView()
                    }
                }.environment(store).preferredColorScheme(.dark).tint(AppColor.accent)
            }
            .alert("Couldn't save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "Please try again.") }
            .task(id: DayWakeKey(active: scenePhase == .active, day: store.policy.key(for: store.now))) {
                guard scenePhase == .active, !AppMotion.snapshotMode else { return }
                let date = store.actionDate()
                let nextDay = store.policy.adding(days: 1, to: store.policy.start(of: date))
                do { try await Task.sleep(for: .seconds(max(1, nextDay.timeIntervalSince(date)))) } catch { return }
                store.refreshSafely()
            }
            .onChange(of: destination) { _, _ in store.refreshSafely() }
            .onChange(of: CoachNotificationRouter.shared.route, initial: true) { _, route in
                guard let route else { return }
                CoachNotificationRouter.shared.route = nil
                switch route {
                case "checkIn": store.presentedSheet = .checkIn
                case "weekly": store.presentedSheet = .weekly
                case "nutrition": store.presentedSheet = .nutrition
                case "objectives": store.presentedSheet = .objectives
                case "recovery": destination = .recovery
                case "progress": destination = .progress
                default: destination = .workout
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { CoachNotifications.synchronize(store: store, requestPermission: false) } }
            .safeAreaInset(edge: .top, spacing: 0) {
                if store.ownerSystem.sleepStartedAt != nil || store.ownerSystem.sickActive {
                    Label(store.ownerSystem.sleepStartedAt != nil ? "SLEEP MODE" : "SICK MODE · TRAINING PROTECTED", systemImage: store.ownerSystem.sleepStartedAt != nil ? "moon.fill" : "shield.lefthalf.filled")
                        .font(.caption2.weight(.medium)).foregroundStyle(AppColor.muted).padding(8).frame(maxWidth: .infinity).background(AppColor.background)
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
                                    Capsule().fill(AppColor.accent.opacity(0.08)).matchedGeometryEffect(id: "selectedTab", in: tabHighlight)
                                        .shadow(color: AppColor.accent.opacity(0.16), radius: 8)
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
