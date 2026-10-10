#if os(macOS)
import SwiftUI

struct MacShoppingView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var session = ShoppingSession()
    @State private var selection: UUID?
    @State private var newItemName = ""
    @State private var failedNames: [String] = []

    static func commands(hasSelection: Bool, checkedCount: Int) -> Set<MacFeatureCommand> {
        var commands: Set<MacFeatureCommand> = []
        if hasSelection { commands.insert(.markBought) }
        if checkedCount > 0 { commands.insert(.finishShopping) }
        return commands
    }

    static func mergeFailedNames(_ existing: [String], adding new: [String]) -> [String] {
        var result = existing
        for name in new where !result.contains(name) {
            result.append(name)
        }
        return result
    }

    private var selectedProduct: StockProduct? {
        selection.flatMap { id in store.shoppingList.first { $0.id == id } }
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                HStack(spacing: 12) {
                    TextField("Add Item", text: $newItemName)
                        .onSubmit(quickAdd)
                        .accessibilityIdentifier("quickAddField")
                    if !session.checkedIds.isEmpty {
                        Button("Finish Shopping (\(session.checkedIds.count))", action: finishShopping)
                            .accessibilityIdentifier("finishShopping")
                    }
                }
            }
            .selectionDisabled()
            .listRowBackground(Color.clear)

            if store.shoppingList.isEmpty {
                ContentUnavailableView("Nothing to Buy", systemImage: "cart",
                                       description: Text("Out and low products show up here."))
                    .selectionDisabled()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(ShoppingGrouping.groups(store.shoppingList)) { group in
                    Section(group.title) {
                        ForEach(group.products) { product in
                            Toggle(product.name, isOn: Binding(
                                get: { session.isChecked(product.id) },
                                set: { _ in session.toggle(product.id) }))
                                .toggleStyle(.checkbox)
                                .tag(product.id)
                                .pastelRow(Palette.shopping)
                        }
                    }
                }
            }
        }
        .flatListStyle()
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let product = store.shoppingList.first(where: { $0.id == ids.first }) {
                Button("Mark as Bought") { markBought(product) }
                Button("Delete", role: .destructive) { delete(product) }
            }
        } primaryAction: { ids in
            if let id = ids.first { session.toggle(id) }
        }
        .onDeleteCommand {
            if let product = selectedProduct { delete(product) }
        }
        .background(ListFocusView(selection: selection))
        .onAppear { prune() }
        .onChange(of: store.shoppingList.map(\.id)) { prune() }
        .onChange(of: selection, initial: true) { updateCommands() }
        .onChange(of: session.checkedIds) { updateCommands() }
        .onChange(of: model.requestedCommand) { _, command in run(command) }
        .alert("Could Not Update", isPresented: Binding(
            get: { !failedNames.isEmpty },
            set: { if !$0 { failedNames = [] } }
        )) {
            Button("OK") { failedNames = [] }
        } message: {
            Text("Failed for: \(failedNames.joined(separator: ", ")). Try again.")
        }
    }

    private func updateCommands() {
        model.availableCommands = Self.commands(hasSelection: selectedProduct != nil,
                                                checkedCount: session.checkedIds.count)
    }

    private func prune() {
        session.prune(validIds: Set(store.shoppingList.map(\.id)))
    }

    private func quickAdd() {
        guard let product = ShoppingSession.quickAddProduct(named: newItemName) else { return }
        newItemName = ""
        Task {
            do { try await store.addProduct(product) } catch {
                failedNames = Self.mergeFailedNames(failedNames, adding: [product.name])
            }
        }
    }

    private func markBought(_ product: StockProduct) {
        Task {
            do { try await store.replenish(product) } catch {
                failedNames = Self.mergeFailedNames(failedNames, adding: [product.name])
            }
        }
    }

    private func delete(_ product: StockProduct) {
        Task { try? await store.deleteProduct(product, undoManager: undoManager, named: "Delete Shopping Item") }
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
            if !failed.isEmpty { failedNames = Self.mergeFailedNames(failedNames, adding: failed) }
        }
    }

    private func run(_ command: MacFeatureCommand?) {
        guard let command else { return }
        model.requestedCommand = nil
        switch command {
        case .markBought:     if let product = selectedProduct { markBought(product) }
        case .finishShopping: finishShopping()
        default:              break
        }
    }
}
#endif
