import SwiftUI

struct EventContextMenu: View {
    let event: PetEvent
    let petName: String

    @Environment(SupabaseStore.self) private var store

    var body: some View {
        Menu {
            ForEach(CalendarService.ReminderOffset.allCases, id: \.self) { offset in
                Button(offset.label) {
                    Task { await CalendarService.addPetEvent(event, petName: petName, reminder: offset) }
                }
            }
        } label: { Label("Add to calendar", systemImage: "calendar.badge.plus") }

        Button(role: .destructive) {
            Task { try? await store.deleteEvent(event) }
        } label: { Label("Delete", systemImage: "trash") }
    }
}
