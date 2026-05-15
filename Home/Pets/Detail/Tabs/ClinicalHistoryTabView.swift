import SwiftUI

struct ClinicalHistoryTabView: View {
    let pet: Pet
    @Environment(DataStore.self) private var store
    @State private var showAdd = false
    @State private var selectedEntry: ClinicalEntry? = nil

    var entries: [ClinicalEntry] { store.clinicalEntries(for: pet.id) }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("No Clinical History", systemImage: "clock.arrow.circlepath",
                    description: Text("Tap + to add a clinical entry."))
                    .listRowBackground(Color.clear)
            }
            ForEach(entries) { entry in
                Button { selectedEntry = entry } label: {
                    ClinicalEntryRow(entry: entry, fileCount: store.files(for: pet.id, linkedTo: .clinicalEntry(entry.id)).count)
                }
                .buttonStyle(.plain)
                .swipeActions { Button("Delete", role: .destructive) { delete(entry) } }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) { AddClinicalEntrySheet(petId: pet.id) }
        .sheet(item: $selectedEntry) { entry in ClinicalEntryDetailView(entry: entry, pet: pet) }
    }

    private func delete(_ entry: ClinicalEntry) {
        let linked = store.files(for: pet.id, linkedTo: .clinicalEntry(entry.id))
        linked.forEach { store.deleteFile($0) }
        store.data.clinicalEntries.removeAll { $0.id == entry.id }
        store.save()
    }
}
