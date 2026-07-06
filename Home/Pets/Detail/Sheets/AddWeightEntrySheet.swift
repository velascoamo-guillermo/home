import SwiftUI

struct AddWeightEntrySheet: View {
    let petId: UUID
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var weightKg: Double? = nil

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Weight (kg)", value: $weightKg,
                          format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled((weightKg ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let weightKg, weightKg > 0 else { return }
        let entry = WeightEntry(petId: petId, date: date, weightKg: weightKg)
        Task {
            try? await store.addWeightEntry(entry)
            dismiss()
        }
    }
}
