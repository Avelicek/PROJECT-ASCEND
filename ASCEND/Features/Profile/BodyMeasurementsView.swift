import SwiftUI

struct BodyMeasurementsView: View {
    @Environment(AppStore.self) private var store
    @State private var date = Date.now
    @State private var height: Double?
    @State private var chest: Double?
    @State private var waist: Double?
    @State private var hips: Double?
    @State private var biceps: Double?
    @State private var thigh: Double?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "BODY HISTORY", title: "Measurements")
                PremiumCard(role: .inline) {
                    VStack(spacing: 12) {
                        OptionalNumericField(title: "Height · cm", value: $height)
                        Button("Update height") { _ = store.saveOwnerSystem { $0.heightCM = height } }.frame(minHeight: 44)
                    }
                }
                PremiumCard {
                    VStack(spacing: 16) {
                        DatePicker("Measured", selection: $date, in: ...store.actionDate(), displayedComponents: .date)
                        OptionalNumericField(title: "Chest · cm", value: $chest); OptionalNumericField(title: "Waist · cm", value: $waist)
                        OptionalNumericField(title: "Hips · cm", value: $hips); OptionalNumericField(title: "Biceps · cm", value: $biceps); OptionalNumericField(title: "Thigh · cm", value: $thigh)
                        PrimaryAction(title: "Save measurement", symbol: "plus", tint: AppColor.bodyweight) { if store.addMeasurement(.init(date: date, chest: chest, waist: waist, hips: hips, biceps: biceps, thigh: thigh)) { chest = nil; waist = nil; hips = nil; biceps = nil; thigh = nil } }
                    }
                }
                ForEach(store.ownerSystem.measurements.reversed()) { entry in
                    PremiumCard(role: .inline) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                            ForEach(0..<5, id: \.self) { index in
                                if let value = [entry.chest, entry.waist, entry.hips, entry.biceps, entry.thigh][index] { HStack { Text(["Chest", "Waist", "Hips", "Biceps", "Thigh"][index]); Spacer(); Text("\(value.formatted()) cm") }.font(.caption).foregroundStyle(AppColor.muted) }
                            }
                        }
                    }
                }
                if store.ownerSystem.measurements.isEmpty { Text("Your first entry starts a personal history. Nothing is estimated.").font(.caption).foregroundStyle(AppColor.muted) }
            }.padding(20)
        }.featureBackground().toolbar(.visible, for: .navigationBar).navigationTitle("Measurements").onAppear { height = store.ownerSystem.heightCM }
    }
}
