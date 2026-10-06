import SwiftUI

struct EditorToolbar: ViewModifier {
    let title: String
    let save: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    func body(content: Content) -> some View {
        content.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(AppColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
            }
            .alert("Check your entry", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "Please try again.") }
    }
}
extension View { func editor(title: String, save: @escaping () -> Void) -> some View { modifier(EditorToolbar(title: title, save: save)) } }
struct NumericField: View {
    let title: String
    @Binding var value: Double
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 120)
                .accessibilityLabel(title)
        }
    }
}
struct OptionalNumericField: View {
    let title: String
    @Binding var value: Double?
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Not set", value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 120)
                .accessibilityLabel(title)
        }
    }
}
struct HistoricalLogNote: View {
    var body: some View {
        Text("Historical logs update your trends and recovery. Already finalized ELO evaluations stay unchanged.")
            .font(.caption).foregroundStyle(AppColor.muted)
    }
}
