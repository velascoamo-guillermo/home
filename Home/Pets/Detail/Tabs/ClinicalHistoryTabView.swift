// Home/Pets/Detail/Tabs/ClinicalHistoryTabView.swift
import SwiftUI

struct ClinicalHistoryTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
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
                let fileCount = store.files(for: pet.id, linkedToType: "clinicalEntry", linkedToId: entry.id).count
                Button { selectedEntry = entry } label: {
                    ClinicalEntryRow(entry: entry, fileCount: fileCount)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        Task { try? await store.deleteClinicalEntry(entry) }
                    }
                }
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
}
