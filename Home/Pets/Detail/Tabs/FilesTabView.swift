// Home/Pets/Detail/Tabs/FilesTabView.swift
import SwiftUI

struct FilesTabView: View {
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showFilePicker = false
    @State private var selectedFile: PetFile? = nil

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
    var standaloneFiles: [PetFile] { store.files(for: pet.id, linkedToType: "standalone") }

    var body: some View {
        ScrollView {
            if standaloneFiles.isEmpty {
                ContentUnavailableView("No Files", systemImage: "folder",
                    description: Text("Add vet reports, photos, and other documents."))
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(standaloneFiles) { file in
                        FileGridCell(url: store.fileUrl(for: file), sourceType: file.sourceType)
                            .onTapGesture { selectedFile = file }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    Task { try? await store.deleteFile(file) }
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showFilePicker = true }
            }
        }
        .sheet(isPresented: $showFilePicker) {
            FilePickerCoordinator { data, ext in
                _ = try await store.uploadFile(data: data, ext: ext, petId: pet.id,
                                               linkedToType: "standalone", linkedToId: nil)
            }
        }
        .sheet(item: $selectedFile) { file in FilePreviewView(file: file, pet: pet) }
    }
}

private struct FileGridCell: View {
    let url: URL
    let sourceType: FileSourceType

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Palette.surface)
            .frame(height: 100)
            .overlay {
                if sourceType == .document || sourceType == .scan {
                    Image(systemName: "doc.fill").font(.largeTitle).foregroundStyle(.secondary)
                } else {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill().clipped()
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
    }
}
