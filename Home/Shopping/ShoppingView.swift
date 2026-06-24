import SwiftUI

struct ShoppingView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var replenishError: Error?

    private struct MarketGroup: Identifiable {
        let id: String
        let title: String
        let products: [StockProduct]
    }

    private var groups: [MarketGroup] {
        let list = store.shoppingList
        var result: [MarketGroup] = Supermarket.allCases.compactMap { market in
            let items = list.filter { $0.supermarket == market }
            guard !items.isEmpty else { return nil }
            return MarketGroup(id: market.rawValue, title: market.displayName, products: items)
        }
        let unassigned = list.filter { $0.supermarket == nil }
        if !unassigned.isEmpty {
            result.append(MarketGroup(id: "unassigned", title: "Unassigned", products: unassigned))
        }
        return result
    }

    var body: some View {
        Group {
            if store.shoppingList.isEmpty {
                ContentUnavailableView(
                    "Nothing to Buy",
                    systemImage: "cart",
                    description: Text("Out-of-stock products show up here.")
                )
            } else {
                List {
                    ForEach(groups) { group in
                        Section(group.title) {
                            ForEach(group.products) { product in
                                Button {
                                    Task {
                                        do {
                                            try await store.replenish(product)
                                        } catch {
                                            replenishError = error
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                            .accessibilityHidden(true)
                                        Image(systemName: product.icon)
                                            .foregroundStyle(.tint)
                                            .frame(width: 28)
                                        Text(product.name)
                                        Spacer()
                                        if let category = product.category {
                                            Image(systemName: category.icon)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .accessibilityLabel(category.displayName)
                                        }
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(product.name)
                                .accessibilityHint("Marks as bought and replenishes stock")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Shopping")
        .alert("Could Not Update", isPresented: Binding(
            get: { replenishError != nil },
            set: { if !$0 { replenishError = nil } }
        )) {
            Button("OK") { replenishError = nil }
        }
    }
}

#Preview {
    ShoppingView()
        .environment(SupabaseStore())
}
