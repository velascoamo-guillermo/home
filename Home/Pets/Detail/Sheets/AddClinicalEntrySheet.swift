// Home/Pets/Detail/Sheets/AddClinicalEntrySheet.swift
import SwiftUI

struct AddClinicalEntrySheet: View {
    let petId: UUID
    @Environment(SupabaseStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var showFilePicker = false
    @State private var pendingFiles: [PetFile] = []

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Section("Entry") {
                    TextField("Title (e.g. Annual checkup)", text: $title)
                    TextField("Diagnosis / findings", text: $description, axis: .vertical).lineLimit(3...6)
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
            .navigationTitle("New Entry")
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
        let entry = ClinicalEntry(petId: petId, date: date, title: title, description: description)
        Task {
            try? await store.addClinicalEntry(entry)
            for file in pendingFiles {
                if let i = store.files.firstIndex(where: { $0.id == file.id }) {
                    var updated = store.files[i]
                    updated.linkedToType = "clinicalEntry"
                    updated.linkedToId = entry.id
                    try? await store.updateFileLink(updated)
                }
            }
            dismiss()
        }
    }
}
