import SwiftUI

@main @MainActor struct AscendApp: App {
    @UIApplicationDelegateAdaptor(AscendNotificationDelegate.self) private var notificationDelegate
    @State private var store: AppStore?
    @State private var startupError: String?
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    Group { if store.ownerSystem.onboardingComplete { RootView() } else { OnboardingView() } }
                        .environment(store).id(store.replacementID)
                        .onChange(of: store.replacementID) { _, _ in if let replacement = store.replacementStore { self.store = replacement
                            if !replacement.container.configurations.allSatisfy(\.isStoredInMemoryOnly) { Task { await Task.yield(); do { try OwnerStoreLocation.cleanRetiredData() } catch { replacement.errorMessage = "The previous store will be cleaned on next launch: \(error.localizedDescription)" } } }
                        } }
                }
                else if let startupError {
                    VStack(spacing: 24) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                        Text("Your data stays yours.").font(.title2.bold())
                        Text("ASCEND couldn't open its local store. No data has been replaced.\n\n\(startupError)").font(.subheadline)
                        Button("Retry", action: load).buttonStyle(.borderedProminent)
                    }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColor.background)
                } else {
                    VStack(spacing: 20) {
                        AscendMark().fill(AppColor.text).frame(width: 92, height: 92)
                        Text("ASCEND").font(.system(.title, design: .rounded, weight: .bold)).tracking(8)
                        ProgressView().tint(AppColor.accent)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColor.background).task { load() }
                }
            }.preferredColorScheme(.dark).tint(AppColor.accent)
                .onChange(of: scenePhase) { _, phase in if phase == .active { store?.refreshSafely() } }
        }
    }
    private func load() {
        do {
            let demo: Bool
            let launchDate: Date
            let clock: () -> Date
            #if DEBUG
            demo = ProcessInfo.processInfo.arguments.contains("--demo")
            if demo && ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                // Freeze only the in-memory UI-test fixture so midnight cannot change its ledger.
                launchDate = Date(timeIntervalSince1970: 1_791_288_000) // 2026-10-06 12:00 UTC
                let fixtureDate = launchDate
                clock = { fixtureDate }
            } else {
                launchDate = .now
                clock = { .now }
            }
            #else
            demo = false
            launchDate = .now
            clock = { .now }
            #endif
            var testFolder: URL?
            var memoryOnly = demo
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--fresh-ui-testing") { memoryOnly = true }
            if ProcessInfo.processInfo.arguments.contains("--owner-fixture"), let testID = ProcessInfo.processInfo.environment["ASCEND_TEST_RUN"], UUID(uuidString: testID) != nil {
                testFolder = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ASCEND-UITests-" + testID, isDirectory: true)
                if let testFolder { try FileManager.default.createDirectory(at: testFolder, withIntermediateDirectories: true) }
                memoryOnly = false
            }
            #endif
            let container = try PersistenceController.makeContainer(inMemory: memoryOnly, folder: testFolder)
            let loaded = try AppStore(container: container, demo: demo, now: launchDate, clock: clock, storageFolder: testFolder)
            #if DEBUG
            if testFolder != nil && !loaded.ownerSystem.onboardingComplete {
                _ = loaded.saveOwnerSystem { state in
                    state.onboardingComplete = true
                    if ProcessInfo.processInfo.arguments.contains("--fixture-recorded-sleep") { state.sleepStartedAt = launchDate.addingTimeInterval(-8 * 3600) }
                }
            }
            #endif
            store = loaded
            startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}
