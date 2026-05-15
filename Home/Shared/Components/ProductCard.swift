import SwiftUI

struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: product.icon)
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .frame(height: 60)

            Text(product.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(product.price)
                .font(.title3)
                .bold()
                .foregroundStyle(.tint)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }
}
