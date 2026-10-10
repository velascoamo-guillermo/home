#if os(macOS)
import SwiftUI

struct MacSidebarView: View {
    @Bindable var model: MacWindowModel
    @Environment(SupabaseStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var petToDelete: Pet?
    @State private var deleteError: String?

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
                Button("Open in New Window") { openWindow(value: MacWindowSeed.new(item)) }
                if case .pet(let id) = item, let pet = store.pets.first(where: { $0.id == id }) {
                    Button("Delete Pet…", role: .destructive) { petToDelete = pet }
                }
            }
        } primaryAction: { items in
            if let item = items.first { model.selection = item }
        }
        .confirmationDialog(
            "Delete \(petToDelete?.name ?? "")?",
            isPresented: Binding(get: { petToDelete != nil }, set: { if !$0 { petToDelete = nil } }),
            titleVisibility: .visible,
            presenting: petToDelete
        ) { pet in
            Button("Delete Pet", role: .destructive) {
                Task {
                    do { try await store.deletePet(pet) } catch { deleteError = error.localizedDescription }
                }
            }
        } message: { pet in
            Text("Also removes \(store.appointments(for: pet.id).count) appointments, \(store.events(for: pet.id).count) events, \(store.clinicalEntries(for: pet.id).count) clinical entries, \(store.weightEntries(for: pet.id).count) weight entries and \(store.files(for: pet.id).count) files. This can't be undone.")
        }
        .alert("Couldn't Delete Pet", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK") {}
        } message: {
            Text(deleteError ?? "")
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
