// Home/Pets/Detail/Tabs/VetTabView.swift
import SwiftUI

struct VetTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            if let vet = store.veterinarian {
                VetCard(vet: vet).padding()
            } else {
                ContentUnavailableView(
                    "No Veterinarian",
                    systemImage: "stethoscope",
                    description: Text("Add your vet's contact information.")
                )
                .padding(.top, 60)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(store.veterinarian == nil ? "Add Vet" : "Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            VetEditSheet(existing: store.veterinarian)
        }
    }
}

private struct VetCard: View {
    let vet: Veterinarian
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(vet.name, systemImage: "person.fill").font(.headline)
            Label(vet.clinicName, systemImage: "building.2.fill")
                .font(.subheadline).foregroundStyle(.secondary)
            Divider()
            if !vet.phone.isEmpty {
                Link(destination: URL(string: "tel:\(vet.phone.replacingOccurrences(of: " ", with: ""))")!) {
                    Label(vet.phone, systemImage: "phone.fill")
                }
            }
            if !vet.address.isEmpty {
                Link(destination: URL(string: "maps://?q=\(vet.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                    Label(vet.address, systemImage: "map.fill")
                }
            }
            if !vet.notes.isEmpty {
                Divider()
                Text(vet.notes).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
