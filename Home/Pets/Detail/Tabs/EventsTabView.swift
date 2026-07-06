// Home/Pets/Detail/Tabs/EventsTabView.swift
import SwiftUI
import EventKit

struct EventsTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var selectedEvent: PetEvent? = nil

    var events: [PetEvent] { store.events(for: pet.id) }

    var body: some View {
        List {
            if events.isEmpty {
                ContentUnavailableView("No Events", systemImage: "list.bullet",
                    description: Text("Track vaccines, grooming, medications and more."))
                    .listRowBackground(Color.clear)
            }
            ForEach(events) { event in
                Button { selectedEvent = event } label: { EventRow(event: event) }
                    .buttonStyle(.plain)
                    .contextMenu { EventContextMenu(event: event, petName: pet.name) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddEventSheet(petId: pet.id) }
        .sheet(item: $selectedEvent) { event in EventDetailView(event: event, pet: pet) }
    }
}
