// Home/Pets/Detail/Tabs/AppointmentsTabView.swift
import SwiftUI

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
                            .swipeActions(edge: .trailing) {
                                Button("Cancel", role: .destructive) {
                                    Task { try? await store.updateAppointmentStatus(appt, status: .cancelled) }
                                }
                                Button("Done") {
                                    Task { try? await store.updateAppointmentStatus(appt, status: .done) }
                                }.tint(.green)
                            }
                    }
                }
            }
            if !past.isEmpty {
                Section("Past") {
                    ForEach(past) { appt in
                        AppointmentRow(appointment: appt)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    Task { try? await store.deleteAppointment(appt) }
                                }
                            }
                    }
                }
            }
        }
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.reason).font(.headline)
                Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if !appointment.notes.isEmpty {
                    Text(appointment.notes).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(appointment.status.rawValue.capitalized)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(statusColor.opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor)
        }
    }
}
