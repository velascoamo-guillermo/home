import SwiftUI

struct MealProductPicker: View {
    @Environment(SupabaseStore.self) private var store
    @Binding var links: [MealEntry.Link]

    var body: some View {
        ForEach(store.stockProducts.filter { $0.category == .food }) { product in
            let index = links.firstIndex { $0.product.id == product.id }
            Button {
                if let index {
                    links.remove(at: index)
                } else {
                    links.append(MealEntry.Link(product: product, quantity: 1))
                }
            } label: {
                HStack {
                    Image(systemName: index != nil ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(index != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(product.name)
                    Spacer()
                    if let index {
                        Stepper(
                            "\(links[index].quantity)",
                            value: $links[index].quantity,
                            in: 1...999
                        )
                        .labelsHidden()
                        Text("\(links[index].quantity)").monospacedDigit().frame(width: 28)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}
