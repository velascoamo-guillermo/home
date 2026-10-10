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
    @State private var schedule: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Doctor") {
                    TextField("Name", text: $name)
                    TextField("Clinic", text: $clinicName)
                }
                Section("Contact") {
                    TextField("Phone", text: $phone).platformKeyboard(.phonePad)
                    TextField("Address", text: $address)
                }
                Section("Schedule") {
                    TextField("e.g. Mon–Fri 9:00–19:00", text: $schedule, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Notes") {
                    TextField("Specialty, emergency line...", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(existing == nil ? "Add Vet" : "Edit Vet")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let vet = Veterinarian(
                            id: existing?.id ?? UUID(),
                            name: name, clinicName: clinicName,
                            phone: phone, address: address,
                            schedule: schedule, notes: notes
                        )
                        Task {
                            if existing == nil {
                                try? await store.addVet(vet)
                            } else {
                                try? await store.updateVet(vet)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || clinicName.isEmpty)
                }
            }
            .onAppear {
                if let v = existing {
                    name = v.name; clinicName = v.clinicName
                    phone = v.phone; address = v.address
                    schedule = v.schedule; notes = v.notes
                }
            }
        }
        .platformSheet()
    }
}
