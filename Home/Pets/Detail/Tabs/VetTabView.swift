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
                    .pastelRow(Palette.pets)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { try? await store.deleteVet(vet) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
            }
        }
        .flatListStyle()
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
            HStack(spacing: 10) {
                PetEntryLabel(title: vet.name, meta: vet.clinicName)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
            }
            if !vet.phone.isEmpty || !vet.address.isEmpty || !vet.schedule.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !vet.phone.isEmpty {
                        Link(destination: URL(string: "tel:\(vet.phone.replacingOccurrences(of: " ", with: ""))")!) {
                            contactLabel(vet.phone, systemImage: "phone.fill")
                        }
                    }
                    if !vet.address.isEmpty {
                        Link(destination: URL(string: "maps://?q=\(vet.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                            contactLabel(vet.address, systemImage: "map.fill")
                        }
                    }
                    if !vet.schedule.isEmpty {
                        contactLabel(vet.schedule, systemImage: "clock", tint: Palette.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Palette.surface, in: .rect(cornerRadius: 12))
            }
        }
        .padding(.vertical, 4)
    }

    private func contactLabel(_ text: String, systemImage: String,
                              tint: Color = Palette.accent) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(tint)
    }
}
