import SwiftUI

struct PetDetailView: View {
    let pet: Pet

    var body: some View {
        Text(pet.name)
            .navigationTitle(pet.name)
    }
}
