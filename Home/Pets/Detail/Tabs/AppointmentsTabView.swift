// Home/Pets/Detail/Tabs/AppointmentsTabView.swift
import SwiftUI
import EventKit

struct AppointmentsTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false

    private var upcoming: [Appointment] {
        store.appointments(for: pet.id).filter { $0.status == .upcoming }.sorted { $0.date < $1.date }
    }
    private var past: [Appointment] {
        store.appointments(for: pet.id).filter { $0.status != .upcoming }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if upcoming.isEmpty && past.isEmpty {
                ContentUnavailableView("No Appointments", systemImage: "calendar.badge.plus",
                    description: Text("Tap + to schedule a visit."))
                    .listRowBackground(Color.clear)
            }
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { appt in
                        AppointmentRow(appointment: appt)
                            .pastelRow(Palette.pets)
                            .contextMenu {
                                AppointmentContextMenu(appointment: appt, petName: pet.name)
                            }
                    }
                }
            }
            if !past.isEmpty {
                Section("Past") {
                    ForEach(past) { appt in
                        AppointmentRow(appointment: appt)
                            .pastelRow(Palette.pets)
                            .contextMenu {
                                AppointmentContextMenu(appointment: appt, petName: pet.name)
                            }
                    }
                }
            }
        }
        .flatListStyle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddAppointmentSheet(petId: pet.id) }
    }
}

private struct AppointmentRow: View {
    let appointment: Appointment

    private var statusColor: Color {
        switch appointment.status {
        case .upcoming:  return .blue
        case .done:      return .green
        case .cancelled: return .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            PetEntryLabel(
                title: appointment.reason,
                meta: appointment.date.formatted(date: .abbreviated, time: .shortened),
                detail: appointment.notes
            )
            // White, not Palette.onAccent: these are saturated system status colours in
            // both appearances, unlike the app's pale accent that onAccent is tuned for.
            Text(appointment.status.rawValue.capitalized)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(statusColor, in: .capsule)
                .foregroundStyle(.white)
        }
    }
}
