// Home/Pets/Detail/Sheets/AddAppointmentSheet.swift
import SwiftUI

struct AddAppointmentSheet: View {
    let petId: UUID
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var reason: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date & Time", selection: $date)
                Section("Details") {
                    TextField("Reason for visit", text: $reason)
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let appt = Appointment(petId: petId, date: date, reason: reason, notes: notes, status: .upcoming)
                        Task {
                            try? await store.addAppointment(appt)
                            dismiss()
                        }
                    }
                    .disabled(reason.isEmpty)
                }
            }
        }
    }
}
