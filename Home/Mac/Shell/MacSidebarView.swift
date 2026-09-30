#if os(macOS)
import SwiftUI

struct MacSidebarView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        List(selection: selectionBinding) {
            Label("Today", systemImage: SidebarItem.today.systemImage)
                .tag(SidebarItem.today)
            Section("Household") {
                ForEach(SidebarItem.household, id: \.self) { item in
                    Label(item.fixedTitle ?? "", systemImage: item.systemImage)
                        .tag(item)
                }
            }
            Section("Pets") {
                ForEach(SidebarModel.petRows(store.pets)) { pet in
                    Label(pet.name, systemImage: SidebarItem.pet(pet.id).systemImage)
                        .tag(SidebarItem.pet(pet.id))
                }
                if store.pets.isEmpty {
                    Button("Add Pet…") { model.perform(.newPet) }
                        .buttonStyle(.borderless)
                }
            }
        }
        .listStyle(.sidebar)
        .contextMenu(forSelectionType: SidebarItem.self) { items in
            if let item = items.first {
                Button("Open in New Window") { openWindow(value: item) }
            }
        } primaryAction: { items in
            if let item = items.first { model.selection = item }
        }
    }

    private var selectionBinding: Binding<SidebarItem?> {
        Binding(
            get: { model.selection },
            set: { new in
                guard let new else { return }
                model.searchText = ""
                model.selection = new
            })
    }
}
#endif
