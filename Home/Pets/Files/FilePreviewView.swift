// Home/Pets/Files/FilePreviewView.swift
import SwiftUI
import PDFKit

struct FilePreviewView: View {
    let file: PetFile
    let pet: Pet
    @Environment(SupabaseStore.self) private var store
    @State private var showExtraction = false

    private var fileURL: URL { store.fileUrl(for: file) }
    private var canExtract: Bool { file.sourceType == .document || file.sourceType == .scan }

    var body: some View {
        NavigationStack {
            Group {
                if file.sourceType == .photo {
                    ScrollView([.horizontal, .vertical]) {
                        AsyncImage(url: fileURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .padding()
                    }
                } else if file.sourceType == .document || file.sourceType == .scan {
                    PDFKitView(url: fileURL)
                } else {
                    ContentUnavailableView("Cannot Preview", systemImage: "doc.questionmark",
                        description: Text("This file type cannot be previewed."))
                }
            }
            .navigationTitle(file.displayName)
            .inlineNavigationTitle()
            .toolbar {
                if canExtract {
                    ToolbarItem(placement: .trailingBar) {
                        Button("Extract Info", systemImage: "sparkles") {
                            showExtraction = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showExtraction) {
                ExtractionResultSheet(file: file, pet: pet)
            }
        }
        .platformSheet()
    }
}

#if os(macOS)
struct PDFKitView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
#else
struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
#endif
