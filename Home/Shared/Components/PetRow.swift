import SwiftUI

struct PetRow: View {
    let pet: Pet

    var body: some View {
        HStack {
            Image(systemName: pet.type == "Dog" ? "dog.fill" : "cat.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(pet.name)
                    .font(.headline)
                Text("\(pet.breed) • \(pet.type)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
