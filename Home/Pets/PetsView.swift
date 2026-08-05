import SwiftUI

struct PetsView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var showAddPet = false
    @State private var petToDelete: Pet? = nil
    @Namespace private var heroNamespace

    var body: some View {
        List(store.pets) { pet in
            NavigationLink(value: pet) {
                PetRow(pet: pet)
            }
            .matchedTransitionSource(id: pet.id, in: heroNamespace)
            .contextMenu {
                Button(role: .destructive) {
                    petToDelete = pet
                } label: { Label("Delete", systemImage: "trash") }
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
        .confirmationDialog(
            "Delete \(petToDelete?.name ?? "")?",
            isPresented: Binding(
                get: { petToDelete != nil },
                set: { if !$0 { petToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: petToDelete
        ) { pet in
            Button("Delete Pet", role: .destructive) {
                Task { try? await store.deletePet(pet) }
            }
        } message: { pet in
            Text("Also removes \(store.appointments(for: pet.id).count) appointments, \(store.events(for: pet.id).count) events, \(store.clinicalEntries(for: pet.id).count) clinical entries, \(store.weightEntries(for: pet.id).count) weight entries and \(store.files(for: pet.id).count) files.")
        }
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
