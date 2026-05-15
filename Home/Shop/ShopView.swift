import SwiftUI

struct ShopView: View {
    private let products: [Product] = [
        Product(name: "Premium Dog Food", price: "$29.99", icon: "bowl.fill"),
        Product(name: "Cat Toy Set", price: "$15.99", icon: "sparkles"),
        Product(name: "Pet Bed", price: "$49.99", icon: "bed.double.fill"),
        Product(name: "Leash & Collar", price: "$19.99", icon: "link")
    ]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(products) { product in
                        ProductCard(product: product)
                    }
                }
                .padding()
            }
            .navigationTitle("Pet Shop")
        }
    }
}

#Preview {
    ShopView()
}
