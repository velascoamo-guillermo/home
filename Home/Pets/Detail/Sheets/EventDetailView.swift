// Home/Pets/Detail/Sheets/EventDetailView.swift
import SwiftUI

struct EventDetailView: View {
    let event: PetEvent
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    var files: [PetFile] {
        store.files(for: pet.id, linkedToType: "event", linkedToId: event.id)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Category") { Label(event.category.label, systemImage: event.category.icon) }
                    LabeledContent("Date") { Text(event.date.formatted(date: .long, time: .omitted)) }
                    if let v = event.value { LabeledContent("Value", value: v) }
                    if !event.notes.isEmpty { Text(event.notes).font(.subheadline) }
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
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilePicker) {
                FilePickerCoordinator { data, ext in
                    try await store.uploadFile(data: data, ext: ext, petId: pet.id,
                                               linkedToType: "event", linkedToId: event.id)
                }
            }
            .sheet(item: $selectedFile) { file in FilePreviewView(file: file, pet: pet) }
        }
    }
}
