import SwiftUI

struct StockProductRow: View {
    let product: StockProduct
    var onSetLevel: ((StockLevel) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.headline)
                if let supermarket = product.supermarket {
                    Text(supermarket.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let onSetLevel {
                Button {
                    guard product.level > .out else { return }
                    onSetLevel(product.level.steppedDown())
                } label: {
                    levelIndicator
                }
                .buttonStyle(.borderless)
                .opacity(product.level == .out ? 0.55 : 1)
                .sensoryFeedback(.decrease, trigger: product.level) { old, new in new < old }
                .accessibilityLabel(accessibilityText)
                .accessibilityHint(product.level == .out ? "Already out of stock" : "Double tap to lower level")
                .accessibilityIdentifier("stockGauge-\(product.name)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: onSetLevel(product.level.steppedUp())
                    case .decrement: onSetLevel(product.level.steppedDown())
                    @unknown default: break
                    }
                }
            } else {
                levelIndicator
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityText)
            }
        }
        .contentShape(.rect)
    }

    private var accessibilityText: String {
        "\(product.name), \(product.level.displayName)"
    }

    private var levelIndicator: some View {
        HStack(spacing: 8) {
            StockGauge(level: product.level)
            Text(product.level.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .leading)
        }
        .contentShape(.rect)
    }
}
