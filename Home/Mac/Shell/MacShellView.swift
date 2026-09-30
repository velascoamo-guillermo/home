#if os(macOS)
import SwiftUI

struct MacShellView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store

    var body: some View {
        NavigationSplitView {
            MacSidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            MacDetailView(model: model)
        }
        .navigationTitle(SidebarModel.title(for: model.selection, pets: store.pets))
        .sheet(item: $model.pendingAction) { action in
            MacNewItemSheet(action: action, budgetMonth: model.budgetMonth)
        }
    }
}
#endif
