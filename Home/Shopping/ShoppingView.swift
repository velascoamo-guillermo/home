import SwiftUI

struct ShoppingView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var session = ShoppingSession()
    @State private var newItemName = ""
    @State private var failedNames: [String] = []

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
        List {
            Section {
                TextField("Add item…", text: $newItemName)
                    .onSubmit(quickAdd)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("quickAddField")
                    .pastelRow(Palette.surface)
            }
            if store.shoppingList.isEmpty {
                ContentUnavailableView(
                    "Nothing to Buy",
                    systemImage: "cart",
                    description: Text("Out and low products show up here.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.products) { product in
                            row(for: product)
                        }
                    }
                }
            }
        }
        .flatListStyle()
        .navigationTitle("Shopping")
        .safeAreaInset(edge: .bottom) {
            if !session.checkedIds.isEmpty {
                Button(action: finishShopping) {
                    Text("Finish shopping (\(session.checkedIds.count))")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("finishShopping")
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onAppear { pruneChecked() }
        .onChange(of: store.shoppingList.map(\.id)) { pruneChecked() }
        .alert("Could Not Update", isPresented: Binding(
            get: { !failedNames.isEmpty },
            set: { if !$0 { failedNames = [] } }
        )) {
            Button("OK") { failedNames = [] }
        } message: {
            Text("Failed for: \(failedNames.joined(separator: ", ")). Try again.")
        }
    }

    private func row(for product: StockProduct) -> some View {
        let checked = session.isChecked(product.id)
        return Button {
            session.toggle(product.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
                Text(product.name)
                    .strikethrough(checked)
                    .foregroundStyle(checked ? .secondary : .primary)
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .pastelRow(Palette.shopping)
        .accessibilityLabel(product.name)
        .accessibilityHint(checked ? "Unchecks this item" : "Checks this item off the list")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { try? await store.deleteProduct(product) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func quickAdd() {
        guard let product = ShoppingSession.quickAddProduct(named: newItemName) else { return }
        newItemName = ""
        Task {
            do {
                try await store.addProduct(product)
            } catch {
                failedNames = [product.name]
            }
        }
    }

    private func finishShopping() {
        let ids = session.checkedIds
        let products = store.shoppingList.filter { ids.contains($0.id) }
        Task {
            var succeeded = Set<UUID>()
            var failed: [String] = []
            for product in products {
                do {
                    try await store.replenish(product)
                    succeeded.insert(product.id)
                } catch {
                    failed.append(product.name)
                }
            }
            session.uncheck(succeeded)
            if !failed.isEmpty { failedNames = failed }
        }
    }

    private func pruneChecked() {
        session.prune(validIds: Set(store.shoppingList.map(\.id)))
    }
}

#Preview {
    ShoppingView()
        .environment(SupabaseStore())
}
