import SwiftUI

struct PetsView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAddPet = false
    @Namespace private var heroNamespace

    var body: some View {
        List(store.pets) { pet in
            NavigationLink(value: pet) {
                PetRow(pet: pet)
            }
            .matchedTransitionSource(id: pet.id, in: heroNamespace)
            .swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) {
                    Task { try? await store.deletePet(pet) }
                }
            }
        }
        .navigationTitle("My Pets")
        .navigationDestination(for: Pet.self) { pet in
            PetDetailView(pet: pet)
                .navigationTransition(.zoom(sourceID: pet.id, in: heroNamespace))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Pet", systemImage: "plus") { showAddPet = true }
            }
        }
        .sheet(isPresented: $showAddPet) { AddPetSheet() }
    }
}

private struct AddPetSheet: View {
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type = "Dog"
    @State private var breed = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()

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
                Section {
                    Toggle("Add Birthday", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("Birthday", selection: $birthday,
                                   in: ...Date.now,
                                   displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Add Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let pet = Pet(name: name, type: type, breed: breed,
                                      birthday: hasBirthday ? birthday : nil)
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
