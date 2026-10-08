import SwiftUI
import UniformTypeIdentifiers

extension UTType { static let ascendBackup = UTType(exportedAs: "com.karel.projectascend.backup", conformingTo: .json) }
struct AscendBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.ascendBackup, .json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { guard let data = configuration.file.regularFileContents else { throw OwnerSystemError.invalid }; self.data = data }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct DataVaultView: View {
    @Environment(AppStore.self) private var store
    @State private var export = false
    @State private var importing = false
    @State private var document = AscendBackupDocument(data: Data())
    @State private var pending: AscendBackupEnvelope?
    @State private var confirmRestore = false
    @State private var resetting = false
    @State private var notice: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "OWNER DATA", title: "Your data vault")
                PremiumCard(role: .hero, tint: AppColor.blue) {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "BACKUP")
                        Text("Keep a complete copy of your ASCEND system.").font(.title3.weight(.medium))
                        PrimaryAction(title: "Export ASCEND Backup", symbol: "square.and.arrow.up", tint: AppColor.blue) { prepareExport() }.accessibilityIdentifier("data.export")
                        Button("Restore from Backup", systemImage: "arrow.down.doc") { importing = true }.frame(minHeight: 48).accessibilityIdentifier("data.restore")
                        Text("Versioned local file · includes history, routines, settings and unfinished training. Store it somewhere you trust.").font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                PremiumCard(role: .glass) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "STORAGE / PRIVACY")
                        Text("Local first. No account. No cloud dependency.").font(.headline)
                        Text("ASCEND has no analytics or tracking. Export and restore happen only when you choose. Backups contain your personal data and are not encrypted by ASCEND; Files storage protection applies separately.").font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                DisclosureGroup("Third-party anatomy & license") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Z-Anatomy · The open source atlas of anatomy · CC BY-SA 4.0. BodyParts3D · The Database Center for Life Science · CC BY-SA 2.1 Japan. Original model: Kousaku Okubo. Anatomy/model design: Gauthier Kervyn. Source distribution: Lluis Vinent.").font(.caption)
                        Text("ASCEND modifies only the derived model: muscle-only selection, mobile mesh reduction, shared graphite material, stable mesh identifiers and Y-up USDZ conversion. The derived asset and its conversion/mapping files remain CC BY-SA 4.0. Source notices and full license travel with the bundled Anatomy folder.").font(.caption).foregroundStyle(AppColor.muted)
                        Link("Z-Anatomy source", destination: URL(string: "https://github.com/LluisV/Z-Anatomy/tree/6c7f9016bd5899ac8edafd31b9900c151df42ed6/Resources/Models")!)
                        Link("CC BY-SA 4.0 license", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    }.padding(.top, 12)
                }.font(.caption).tint(AppColor.muted)
                PremiumCard(role: .inline) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "DANGER ZONE")
                        Text("Export backup first.").font(.headline)
                        Text("Start again with an empty personal system. Exported copies in Files stay under your control.").font(.caption).foregroundStyle(AppColor.muted)
                        Button("Reset ASCEND", role: .destructive) { resetting = true }.frame(minHeight: 48).accessibilityIdentifier("data.reset")
                    }
                }
                if let notice { Text(notice).font(.caption).foregroundStyle(AppColor.muted) }
            }.padding(20)
        }.featureBackground().accessibilityIdentifier("screen.data").toolbar(.visible, for: .navigationBar).navigationTitle("Data").navigationBarTitleDisplayMode(.inline)
            .fileExporter(isPresented: $export, document: document, contentType: .ascendBackup, defaultFilename: "ASCEND-\(store.policy.key(for: store.actionDate())).ascendbackup") { result in
                switch result { case .success: notice = "Backup exported."; case .failure(let error): store.errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.ascendBackup, .json, .data]) { result in
                do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 100_000_001) <= 100_000_000 else { throw InputError.invalid("This backup is too large to open safely.") }; pending = try AscendBackupEnvelope.decode(Data(contentsOf: url, options: .mappedIfSafe)); confirmRestore = true }
                catch { store.errorMessage = "No data changed: \(error.localizedDescription)" }
            }
            .sheet(isPresented: $confirmRestore) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 24) {
                        FeatureHeader(eyebrow: "VALIDATED BACKUP", title: "Restore your system?")
                        if let pending { Text(pending.payload.summary).font(.subheadline); Text("Exported \(pending.exportedAt.formatted(date: .abbreviated, time: .shortened)) · ASCEND \(pending.appVersion)").font(.caption).foregroundStyle(AppColor.muted) }
                        Text("This replaces the complete current local system. Export your current data first if you want to keep it.").font(.subheadline)
                        PrimaryAction(title: "Replace & restore", symbol: "arrow.down.doc", tint: AppColor.blue) { if let pending, store.replaceOwnerData(with: pending) { confirmRestore = false } }.accessibilityIdentifier("data.confirm.restore")
                        Spacer()
                    }.padding(24).featureBackground().toolbar(.visible, for: .navigationBar).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { confirmRestore = false; pending = nil } } }
                }.preferredColorScheme(.dark)
            }
            .sheet(isPresented: $resetting) { NavigationStack { ResetAscendView().environment(store) }.preferredColorScheme(.dark) }
            .alert("Data unchanged", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
    }
    private func prepareExport() {
        do { let envelope = try store.backupEnvelope(); let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]; document = .init(data: try encoder.encode(envelope)); export = true }
        catch { store.errorMessage = error.localizedDescription }
    }
}
struct ResetAscendView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var consent = false
    @State private var phrase = ""
    @FocusState private var focused: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "START OVER", title: "Reset ASCEND")
                Text("Export a backup before continuing.").font(.headline)
                Button("Back to export backup") { dismiss() }.frame(minHeight: 44)
                Text("Your profile, logs, workouts, routines, Brain preferences and progression will be removed. ASCEND returns to setup.").font(.subheadline).foregroundStyle(AppColor.muted)
                Toggle("I understand that all local ASCEND data will be permanently deleted.", isOn: $consent).accessibilityIdentifier("reset.consent")
                Text("Type RESET ASCEND to continue.").font(.caption)
                TextField("RESET ASCEND", text: $phrase).focused($focused).textInputAutocapitalization(.characters).autocorrectionDisabled().padding(16).background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("reset.phrase")
                PrimaryAction(title: "ERASE & START AGAIN", symbol: "trash", tint: SemanticStatus.low.tint) {
                    guard ResetConsent.allowed(checked: consent, phrase: phrase) else { return }
                    if store.replaceOwnerData(with: nil) { dismiss() }
                }.disabled(!ResetConsent.allowed(checked: consent, phrase: phrase)).accessibilityIdentifier("reset.erase")
            }.padding(24)
        }.featureBackground().toolbar(.visible, for: .navigationBar).navigationTitle("Reset").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; if focused { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } } }
    }
}
