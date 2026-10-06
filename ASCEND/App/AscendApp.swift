import SwiftUI

@main @MainActor struct AscendApp: App {
    @State private var store: AppStore?
    @State private var startupError: String?
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                if let store { RootView().environment(store) }
                else if let startupError {
                    VStack(spacing: 24) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                        Text("Your data stays yours.").font(.title2.bold())
                        Text("ASCEND couldn't open its local store. No data has been replaced.\n\n\(startupError)").font(.subheadline)
                        Button("Retry", action: load).buttonStyle(.borderedProminent)
                    }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColor.background)
                } else {
                    VStack(spacing: 20) {
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
            let container = try PersistenceController.makeContainer(inMemory: demo)
            store = try AppStore(container: container, demo: demo, now: launchDate, clock: clock)
            startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}
