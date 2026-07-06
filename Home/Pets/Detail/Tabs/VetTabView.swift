// Home/Pets/Detail/Tabs/VetTabView.swift
import SwiftUI

struct VetTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showAdd = false
    @State private var editingVet: Veterinarian? = nil

    var body: some View {
        List {
            if store.veterinarians.isEmpty {
                ContentUnavailableView(
                    "No Veterinarians",
                    systemImage: "stethoscope",
                    description: Text("Add your vet's contact information.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(store.veterinarians) { vet in
                VetRow(vet: vet)
                    .onTapGesture { editingVet = vet }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { try? await store.deleteVet(vet) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Vet", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { VetEditSheet(existing: nil) }
        .sheet(item: $editingVet) { vet in VetEditSheet(existing: vet) }
    }
}

private struct VetRow: View {
    let vet: Veterinarian

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vet.name).font(.headline)
                    Text(vet.clinicName).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            if !vet.phone.isEmpty || !vet.address.isEmpty || !vet.schedule.isEmpty {
                Divider()
                if !vet.phone.isEmpty {
                    Link(destination: URL(string: "tel:\(vet.phone.replacingOccurrences(of: " ", with: ""))")!) {
                        Label(vet.phone, systemImage: "phone.fill").font(.subheadline)
                    }
                }
                if !vet.address.isEmpty {
                    Link(destination: URL(string: "maps://?q=\(vet.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                        Label(vet.address, systemImage: "map.fill").font(.subheadline)
                    }
                }
                if !vet.schedule.isEmpty {
                    Label(vet.schedule, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
