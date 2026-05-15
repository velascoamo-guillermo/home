import SwiftUI

struct PetsView: View {
    @State private var pets: [Pet] = [
        Pet(name: "Luna", type: "Dog", breed: "Golden Retriever"),
        Pet(name: "Whiskers", type: "Cat", breed: "Persian"),
        Pet(name: "Buddy", type: "Dog", breed: "Labrador")
    ]

    var body: some View {
        NavigationStack {
            List(pets) { pet in
                PetRow(pet: pet)
            }
            .navigationTitle("My Pets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // placeholder
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    PetsView()
}
