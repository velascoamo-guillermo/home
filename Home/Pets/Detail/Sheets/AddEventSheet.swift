// Home/Pets/Detail/Sheets/AddEventSheet.swift
import SwiftUI

struct AddEventSheet: View {
    let petId: UUID
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var title: String = ""
    @State private var category: EventCategory = .other
    @State private var notes: String = ""
    @State private var value: String = ""
    @State private var showFilePicker = false
    @State private var pendingFiles: [PetFile] = []

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Section("Event") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(EventCategory.allCases, id: \.self) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                    if category == .weight {
                        TextField("Value (e.g. 4.2 kg)", text: $value)
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...4)
                }
                Section("Files") {
                    Button { showFilePicker = true } label: {
                        Label("Attach file", systemImage: "plus.circle")
                    }
                    ForEach(pendingFiles) { file in
                        Label(file.displayName,
                              systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                FilePickerCoordinator { data, ext in
                    let f = try await store.uploadFile(data: data, ext: ext, petId: petId,
                                                       linkedToType: "standalone", linkedToId: nil)
                    pendingFiles.append(f)
                }
            }
        }
    }

    private func save() {
        let event = PetEvent(
            petId: petId, date: date, title: title, category: category,
            notes: notes, value: value.isEmpty ? nil : value
        )
        Task {
            try? await store.addEvent(event)
            for file in pendingFiles {
                if let i = store.files.firstIndex(where: { $0.id == file.id }) {
                    var updated = store.files[i]
                    updated.linkedToType = "event"
                    updated.linkedToId = event.id
                    try? await store.updateFileLink(updated)
                }
            }
            dismiss()
        }
    }
}
