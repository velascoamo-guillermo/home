import SwiftUI

struct PetsView: View {
    @Environment(DataStore.self) private var store
    @State private var showAddPet = false

    var body: some View {
        NavigationStack {
            List(store.data.pets) { pet in
                NavigationLink(value: pet) {
                    PetRow(pet: pet)
                }
            }
            .navigationTitle("My Pets")
            .navigationDestination(for: Pet.self) { pet in
                PetDetailView(pet: pet)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Pet", systemImage: "plus") {
                        showAddPet = true
                    }
                }
            }
        }
    }
}

#Preview {
    PetsView()
        .environment(DataStore())
}
