// Home/Pets/Detail/Sheets/VetEditSheet.swift
import SwiftUI

struct VetEditSheet: View {
    let existing: Veterinarian?
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var clinicName: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Doctor") {
                    TextField("Name", text: $name)
                    TextField("Clinic", text: $clinicName)
                }
                Section("Contact") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Address", text: $address)
                }
                Section("Notes") {
                    TextField("Specialty, hours...", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "Add Vet" : "Edit Vet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let vet = Veterinarian(
                            id: existing?.id ?? UUID(),
                            name: name, clinicName: clinicName,
                            phone: phone, address: address, notes: notes
                        )
                        Task {
                            try? await store.upsertVet(vet)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || clinicName.isEmpty)
                }
            }
            .onAppear {
                if let v = existing {
                    name = v.name; clinicName = v.clinicName
                    phone = v.phone; address = v.address; notes = v.notes
                }
            }
        }
    }
}
