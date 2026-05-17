// Home/Pets/PetsView.swift
import SwiftUI

struct PetsView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAddPet = false

    var body: some View {
        NavigationStack {
            List(store.pets) { pet in
                NavigationLink(value: pet) {
                    PetRow(pet: pet)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        Task { try? await store.deletePet(pet) }
                    }
                }
            }
            .navigationTitle("My Pets")
            .navigationDestination(for: Pet.self) { pet in
                PetDetailView(pet: pet)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Pet", systemImage: "plus") { showAddPet = true }
                }
            }
            .sheet(isPresented: $showAddPet) { AddPetSheet() }
        }
    }
}

private struct AddPetSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type = "Dog"
    @State private var breed = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    Text("Dog").tag("Dog")
                    Text("Cat").tag("Cat")
                    Text("Other").tag("Other")
                }
                TextField("Breed", text: $breed)
            }
            .navigationTitle("Add Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let pet = Pet(name: name, type: type, breed: breed)
                        Task {
                            try? await store.addPet(pet)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || breed.isEmpty)
                }
            }
        }
    }
}

#Preview {
    PetsView().environment(SupabaseStore())
}
