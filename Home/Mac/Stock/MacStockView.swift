#if os(macOS)
import SwiftUI

struct MacStockView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @Environment(\.undoManager) private var undoManager
    @State private var selection: StockProduct.ID?
    @State private var sortOrder = [KeyPathComparator(\StockProduct.name, comparator: .localizedStandard)]
    @State private var filter: StockListModel.Filter = .all
    @State private var category: ProductCategory?

    private var selectedProduct: StockProduct? {
        selection.flatMap { id in store.stockProducts.first { $0.id == id } }
    }

    var body: some View {
        let listModel = StockListModel(products: store.stockProducts, filter: filter, category: category, query: "")
        let rows = listModel.groups.flatMap(\.products).sorted(using: sortOrder)

        VStack(alignment: .leading, spacing: 12) {
            filters(listModel)
                .padding([.horizontal, .top], 16)
            if store.stockProducts.isEmpty {
                ContentUnavailableView("No Stock", systemImage: "shippingbox",
                                       description: Text("Add products you restock with File ▸ New Product."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(rows, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name, comparator: .localizedStandard)
                    TableColumn("Level", value: \.level) { product in
                        Text(product.level.displayName)
                            .foregroundStyle(product.level.needsRestock ? Color.red : Palette.ink)
                    }
                    TableColumn("Category", value: \.categorySortKey) { product in
                        Text(product.category?.displayName ?? "—")
                    }
                    TableColumn("Supermarket", value: \.supermarketSortKey) { product in
                        Text(product.supermarket?.displayName ?? "—")
                    }
                }
                .contextMenu(forSelectionType: StockProduct.ID.self) { ids in
                    if let product = store.stockProducts.first(where: { $0.id == ids.first }) {
                        Button("Mark as Bought") { markBought(product) }
                        StockContextMenu(product: product, onDeleteRequest: { delete($0) })
                    }
                } primaryAction: { ids in
                    if ids.first != nil { model.isInspectorPresented = true }
                }
                .onDeleteCommand {
                    if let product = selectedProduct { delete(product) }
                }
                .background(ListFocusView(selection: selection))
            }
        }
        .gradientCanvas()
        .inspector(isPresented: $model.isInspectorPresented) {
            Group {
                if let product = selectedProduct {
                    AddStockProductSheet(existing: product).id(product.id)
                } else {
                    ContentUnavailableView("No Selection", systemImage: "sidebar.trailing",
                                           description: Text("Select a product to edit it."))
                }
            }
            .inspectorColumnWidth(min: 360, ideal: 400, max: 520)
        }
        .onChange(of: selectedProduct?.id, initial: true) { _, id in
            model.availableCommands = id == nil ? [] : [.markBought]
        }
        .onChange(of: model.requestedCommand) { _, command in
            guard let command else { return }
            model.requestedCommand = nil
            if command == .markBought, let product = selectedProduct { markBought(product) }
        }
    }

    private func filters(_ listModel: StockListModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(listModel.visibleFilters, id: \.self) { option in
                    Chip(title: listModel.title(for: option), fill: Palette.stock,
                         isSelected: listModel.effectiveFilter == option) {
                        filter = StockListModel.toggled(listModel.effectiveFilter, tapped: option)
                    }
                }
            }
            ChipGroup(items: listModel.visibleCategories, selection: $category, fill: Palette.tasks,
                      title: { listModel.title(for: $0) }, systemImage: { $0.icon })
        }
    }

    private func markBought(_ product: StockProduct) {
        Task { try? await store.replenish(product) }
    }

    private func delete(_ product: StockProduct) {
        Task { try? await store.deleteProduct(product, undoManager: undoManager) }
    }
}
#endif
