// Home/Pets/Detail/Sheets/ClinicalEntryDetailView.swift
import SwiftUI

struct ClinicalEntryDetailView: View {
    let entry: ClinicalEntry
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    var files: [PetFile] {
        store.files(for: pet.id, linkedToType: "clinicalEntry", linkedToId: entry.id)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date") {
                        Text(entry.date.formatted(date: .long, time: .omitted))
                    }
                    if !entry.description.isEmpty {
                        Text(entry.description).font(.subheadline)
                    }
                }
                Section("Files") {
                    ForEach(files) { file in
                        Button { selectedFile = file } label: {
                            Label(file.displayName,
                                  systemImage: file.sourceType == .document ? "doc.fill" : "photo.fill")
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                Task { try? await store.deleteFile(file) }
                            }
                        }
                    }
                    Button { showFilePicker = true } label: {
                        Label("Add file", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilePicker) {
                FilePickerCoordinator { data, ext in
                    try await store.uploadFile(data: data, ext: ext, petId: pet.id,
                                               linkedToType: "clinicalEntry", linkedToId: entry.id)
                }
            }
            .sheet(item: $selectedFile) { file in
                FilePreviewView(file: file, pet: pet)
            }
        }
    }
}
