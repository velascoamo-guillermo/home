#if os(macOS)
import SwiftUI

struct MacShellView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationSplitView {
            MacSidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            if model.isSearching {
                MacSearchResultsView(model: model)
            } else {
                MacDetailView(model: model)
            }
        }
        .navigationTitle(SidebarModel.title(for: model.selection, pets: store.pets))
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search tasks, stock, meals, pets")
        .searchFocused($searchFocused)
        .onChange(of: model.isSearchFocused) {
            if model.consumeSearchFocusRequest() { searchFocused = true }
        }
        .onAppear { if model.consumeSearchFocusRequest() { searchFocused = true } }
        .toolbar { MacToolbar(model: model) }
        .sheet(item: sheetAction) { action in
            MacNewItemSheet(action: action, budgetMonth: model.budgetMonth)
        }
    }

    private var sheetAction: Binding<MacPendingAction?> {
        Binding(
            get: { model.pendingAction?.presentsSheet == true ? model.pendingAction : nil },
            set: { model.pendingAction = $0 })
    }
}
#endif
