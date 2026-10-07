import SwiftUI

struct TrainingProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FeatureHeader(eyebrow: "PERSONAL TRAINING", title: "My Gym")
                PremiumCard(role: .hero, tint: AppColor.recovery) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Environment", selection: Binding(get: { store.training.profile.environment }, set: { value in _ = store.editTraining { $0.profile.environment = value } })) {
                            Text("Home gym").tag(TrainingEnvironment.homeGym); Text("Gym").tag(TrainingEnvironment.gym); Text("Outdoors").tag(TrainingEnvironment.outdoors)
                        }.pickerStyle(.segmented)
                        Picker("Goal", selection: Binding(get: { store.training.profile.goal }, set: { value in _ = store.editTraining { $0.profile.goal = value } })) {
                            Text("Strength / muscle").tag(TrainingGoal.strengthAndMuscle); Text("Strength").tag(TrainingGoal.strength); Text("General fitness").tag(TrainingGoal.generalFitness)
                        }.tint(AppColor.recovery)
                        Stepper("Preferred session · \(store.training.profile.sessionMinutes) min", value: Binding(get: { store.training.profile.sessionMinutes }, set: { value in _ = store.editTraining { $0.profile.sessionMinutes = value } }), in: 15...180, step: 5).font(.caption).foregroundStyle(AppColor.secondary)
                    }
                }
                Eyebrow(text: "AVAILABLE EQUIPMENT")
                Text("Select what you own. Unselected equipment stays in the catalog, with availability clearly marked.").font(.caption).foregroundStyle(AppColor.muted)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(GymEquipment.allCases) { equipment in
                        let selected = store.training.profile.equipment.contains(equipment) || equipment == .bodyweight
                        Button {
                            _ = store.editTraining { state in if !state.profile.equipment.insert(equipment).inserted { state.profile.equipment.remove(equipment) } }
                            AppHaptics.selection(enabled: store.settings.hapticsEnabled)
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? AppColor.recovery : AppColor.muted)
                                Text(equipment.title).font(.caption.weight(.medium)).foregroundStyle(selected ? AppColor.text : AppColor.secondary)
                                Spacer(minLength: 0)
                            }.padding(12).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                .background(selected ? AppColor.recovery.opacity(0.09) : AppColor.surface, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(PremiumPressStyle()).disabled(equipment == .bodyweight)
                            .accessibilityIdentifier("gym.equipment.\(equipment.rawValue)").accessibilityValue(selected ? "Available" : "Not available")
                    }
                }
                if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AppColor.warning) }
            }.padding(20)
        }.accessibilityIdentifier("screen.trainingprofile").background(AppColor.background).navigationTitle("Training profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
