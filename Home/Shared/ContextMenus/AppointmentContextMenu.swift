import SwiftUI

struct AppointmentContextMenu: View {
    let appointment: Appointment
    let petName: String

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        if appointment.status == .upcoming {
            Button {
                Task { try? await store.updateAppointmentStatus(appointment, status: .done) }
            } label: { Label("Done", systemImage: "checkmark") }

            Menu {
                ForEach(CalendarService.ReminderOffset.allCases, id: \.self) { offset in
                    Button(offset.label) {
                        Task { await CalendarService.addAppointment(appointment, petName: petName, reminder: offset) }
                    }
                }
            } label: { Label("Add to calendar", systemImage: "calendar.badge.plus") }

            Button(role: .destructive) {
                Task { try? await store.updateAppointmentStatus(appointment, status: .cancelled) }
            } label: { Label("Cancel", systemImage: "xmark.circle") }
        } else {
            Button(role: .destructive) {
                Task { try? await store.deleteAppointment(appointment) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
