import SwiftUI

struct StockProductRow: View {
    let product: StockProduct
    var showsIcon: Bool = true

    private var breakdown: String {
        if product.totalUnits == 0 { return "Out of stock" }
        if product.packages > 0 && product.looseUnits > 0 {
            return "\(product.packages) pkg · \(product.looseUnits) loose"
        }
        if product.packages > 0 { return "\(product.packages) pkg" }
        return "\(product.looseUnits) loose"
    }

    var body: some View {
        HStack(spacing: 12) {
            if showsIcon {
                Image(systemName: product.icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.headline)
                Text(breakdown).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if product.totalUnits == 0 {
                Text("Out of stock")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(.rect(cornerRadius: 6))
            } else {
                Text("\(product.totalUnits)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }
}
