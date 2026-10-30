import SwiftUI

struct ShoppingView: View {
    @Environment(SupabaseStore.self) private var store
    @State private var session = ShoppingSession()
    @State private var newItemName = ""
    @State private var failedNames: [String] = []
    @State private var productToDelete: StockProduct? = nil
    @State private var finishedCount = 0
    @State private var finishPhase = FinishShoppingAction.Phase.idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var finishAction: FinishShoppingAction {
        FinishShoppingAction(count: session.checkedIds.count, phase: finishPhase)
    }

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
        .safeAreaInset(edge: .bottom) { finishCapsule }
        .sensoryFeedback(.success, trigger: finishedCount)
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
        .productDeleteDialog($productToDelete)
    }

    /// Animation is scoped to this container so it never touches the List's row updates.
    private var finishCapsule: some View {
        ZStack {
            if finishAction.isVisible {
                FinishShoppingButton(action: finishAction, perform: finishShopping)
                    .padding(.bottom, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.25),
                   value: finishAction.isVisible)
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
            // No .destructive role: that makes the List optimistically collapse the row on tap,
            // but removal is deferred until the confirmation dialog, which corrupts the batch update.
            Button {
                productToDelete = product
            } label: { Label("Delete", systemImage: "trash") }
            .tint(.red)
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
        guard !products.isEmpty, finishPhase.begin() else { return }
        Task {
            do {
                try await store.replenish(products)
                session.uncheck(Set(products.map(\.id)))
                finishedCount += 1
                finishPhase.succeed()
                try? await Task.sleep(for: .milliseconds(1200))
                finishPhase.dismissConfirmation()
            } catch {
                finishPhase.fail()
                failedNames = products.map(\.name)
            }
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
