import SwiftUI

struct OwnerModeCard: View {
    @Environment(AppStore.self) private var store
    @State private var endingSleep = false
    @State private var sick = false
    var body: some View {
        PremiumCard(role: store.ownerSystem.sleepStartedAt != nil || store.ownerSystem.sickActive ? .hero : .inline, tint: AppColor.sleep) {
            VStack(alignment: .leading, spacing: 14) {
                if let start = store.ownerSystem.sleepStartedAt {
                    Eyebrow(text: "SLEEP MODE"); Text("Sleep in progress").font(.title2.weight(.medium))
                    Text("Started \(start.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(AppColor.muted)
                    PrimaryAction(title: "END SLEEP", symbol: "sunrise", tint: AppColor.sleep) { endingSleep = true }.accessibilityIdentifier("sleep.end")
                } else if store.ownerSystem.sickActive {
                    Eyebrow(text: "RECOVERY PROTECTION"); Text("Sick Mode active").font(.title2.weight(.medium))
                    Text("Training pressure paused. Fuel and sleep remain active.").font(.subheadline).foregroundStyle(AppColor.muted)
                    Button("End Sick Mode", systemImage: "shield") { sick = true }.frame(minHeight: 44).accessibilityIdentifier("sick.end")
                    Button("Start sleep", systemImage: "moon") { store.presentedSheet = .sleepSummary }.frame(minHeight: 44).accessibilityIdentifier("sleep.start")
                } else {
                    HStack {
                        Button("Start sleep", systemImage: "moon") { store.presentedSheet = .sleepSummary }.frame(minHeight: 44).accessibilityIdentifier("sleep.start")
                        Spacer()
                        Button("Sick Mode", systemImage: "shield.lefthalf.filled") { sick = true }.frame(minHeight: 44).accessibilityIdentifier("sick.open")
                    }.font(.caption.weight(.medium)).foregroundStyle(AppColor.muted)
                }
            }
        }
        .onAppear {
            #if DEBUG
            if store.isDemo && AppMotion.snapshotMode && ProcessInfo.processInfo.arguments.contains("--capture-end-sleep") { endingSleep = true }
            #endif
        }
        .sheet(isPresented: $endingSleep) { NavigationStack { EndSleepView(start: store.ownerSystem.sleepStartedAt ?? store.actionDate(), end: store.actionDate()).environment(store) }.preferredColorScheme(.dark) }
        .sheet(isPresented: $sick) { NavigationStack { SickModeView().environment(store).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { sick = false } } } }.preferredColorScheme(.dark) }
    }
}
struct EndSleepView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var quality = 3
    @State private var adjusting = false
    @State private var replace = false
    @State private var cancel = false
    init(start: Date, end: Date) { _start = State(initialValue: start); _end = State(initialValue: end) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "GOOD MORNING", title: "Welcome back")
                PremiumCard(role: .hero, tint: AppColor.sleep) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("\(start.formatted(date: .omitted, time: .shortened)) → \(end.formatted(date: .omitted, time: .shortened))").font(.title2).monospacedDigit()
                        Text(duration).font(.largeTitle.weight(.medium)).monospacedDigit()
                        Text("Time recorded. Adjust it if you were awake.").font(.caption).foregroundStyle(AppColor.muted)
                        Button(adjusting ? "Hide adjustments" : "Adjust") { adjusting.toggle() }.frame(minHeight: 44).accessibilityIdentifier("sleep.adjust")
                        if adjusting {
                            DatePicker("Started", selection: $start, in: ...store.actionDate())
                            DatePicker("Ended", selection: $end, in: ...store.actionDate())
                            Picker("Quality", selection: $quality) { ForEach(1...5, id: \.self) { Text("\($0) / 5").tag($0) } }
                        }
                    }
                }
                if start >= end || end.timeIntervalSince(start) < 360 || end.timeIntervalSince(start) > 86400 { Text("Choose an interval between 6 minutes and 24 hours, or discard an accidental start.").font(.caption).foregroundStyle(SemanticStatus.watch.tint) }
                PrimaryAction(title: "Confirm & check in", symbol: "checkmark", tint: AppColor.sleep) {
                    if store.sleep.contains(where: { $0.dayKey == store.policy.key(for: end) }) { replace = true } else { save(replace: false) }
                }.accessibilityIdentifier("sleep.save")
                Button("Discard this interval", role: .destructive) { cancel = true }.frame(minHeight: 44).accessibilityIdentifier("sleep.discard")
            }.padding(24)
        }.featureBackground(tint: AppColor.sleep).accessibilityIdentifier("screen.endsleep").toolbar(.visible, for: .navigationBar).navigationTitle("Good morning")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Keep resting") { _ = store.saveOwnerSystem { $0.sleepEndedAt = nil } } } }
            .confirmationDialog("Replace the existing sleep log for this wake day?", isPresented: $replace, titleVisibility: .visible) { Button("Replace sleep log") { save(replace: true) }; Button("Cancel", role: .cancel) {} }
            .confirmationDialog("Discard the active interval without creating a sleep log?", isPresented: $cancel, titleVisibility: .visible) { Button("Discard interval", role: .destructive) { store.cancelSleep(); dismiss() } }
            .alert("Check interval", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
    }
    private var duration: String { let minutes = max(0, Int(end.timeIntervalSince(start) / 60)); return "\(minutes / 60) h \(minutes % 60) min" }
    private func save(replace: Bool) { _ = store.finishSleep(start: start, end: end, quality: quality, replace: replace) }
}
struct SickModeView: View {
    @Environment(AppStore.self) private var store
    @State private var note = ""
    @State private var ending = false
    @State private var active = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "RECOVERY FIRST", title: active ? "Sick Mode" : "Feeling sick?")
                PremiumCard(role: .hero, tint: AppColor.blue) {
                    VStack(alignment: .leading, spacing: 18) {
                        Label(active ? "Training protection active" : "Give your system room", systemImage: "shield.lefthalf.filled").font(.headline)
                        Text("ASCEND prioritizes recovery, pauses workout recommendations and protects today’s training goals.").font(.subheadline).foregroundStyle(AppColor.muted)
                        if active {
                            if let interval = store.ownerSystem.sickIntervals.last { Text("Started \(interval.start.formatted())").font(.caption); if !interval.note.isEmpty { Text(interval.note).font(.caption).foregroundStyle(AppColor.muted) } }
                            PrimaryAction(title: "End Sick Mode", symbol: "shield", tint: AppColor.blue) { ending = true }.accessibilityIdentifier("sick.finish")
                        } else {
                            TextField("Optional personal note", text: $note, axis: .vertical).lineLimit(2...4)
                            PrimaryAction(title: "ENABLE SICK MODE", symbol: "shield", tint: AppColor.blue) {
                                store.startSick(note: note)
                                active = store.ownerSystem.sickActive
                            }.accessibilityIdentifier("sick.start")
                        }
                        Text("This is your declaration, not a diagnosis. Manual training remains available.").font(.caption2).foregroundStyle(AppColor.muted)
                    }
                }
            }.padding(24)
        }.featureBackground(tint: AppColor.blue).accessibilityIdentifier("screen.sickmode").toolbar(.visible, for: .navigationBar).navigationTitle("Sick Mode")
            .onAppear { active = store.ownerSystem.sickActive }
            .onChange(of: store.ownerSystem.sickActive) { _, value in active = value }
            .confirmationDialog("End Sick Mode and resume future training recommendations? Protected history will remain protected.", isPresented: $ending, titleVisibility: .visible) {
                Button("End protection") {
                    store.endSick()
                    active = store.ownerSystem.sickActive
                }
                Button("Keep protection", role: .cancel) {}
            }
    }
}
