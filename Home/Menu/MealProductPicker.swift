import SwiftUI

struct MealProductPicker: View {
    @Environment(SupabaseStore.self) private var store
    @Binding var links: [MealEntry.Link]

    var body: some View {
        ForEach(store.stockProducts.filter { $0.category == .food }) { product in
            let isLinked = links.contains { $0.product.id == product.id }
            Button {
                if isLinked {
                    links.removeAll { $0.product.id == product.id }
                } else {
                    links.append(MealEntry.Link(product: product))
                }
            } label: {
                HStack {
                    Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isLinked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .accessibilityHidden(true)
                    Text(product.name)
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isLinked ? .isSelected : [])
        }
    }
}
