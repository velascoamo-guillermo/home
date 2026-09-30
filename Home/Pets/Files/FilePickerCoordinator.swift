// Home/Pets/Files/FilePickerCoordinator.swift
import SwiftUI
import PhotosUI
#if os(iOS)
import VisionKit
#endif

struct FilePickerCoordinator: View {
    var onPick: (Data, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var photoPickerItem: PhotosPickerItem? = nil
    #if os(iOS)
    @State private var showCamera = false
    @State private var showDocPicker = false
    @State private var showScanner = false
    #else
    @State private var showImporter = false
    @State private var importError: String?
    #endif

    var body: some View {
        #if os(iOS)
        iOSBody
        #else
        macBody
        #endif
    }

    #if os(iOS)
    private var iOSBody: some View {
        NavigationStack {
            List {
                Button { showCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                Button { showDocPicker = true } label: { Label("Choose File", systemImage: "doc") }
                Button { showScanner = true } label: { Label("Scan Document", systemImage: "doc.viewfinder") }
            }
            .navigationTitle("Add File")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    try? await onPick(data, "jpg")
                    await MainActor.run { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    Task { try? await onPick(data, "jpg") }
                }
                dismiss()
            }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPicker { data in
                Task {
                    try? await onPick(data, "pdf")
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { pdfData in
                Task {
                    try? await onPick(pdfData, "pdf")
                    dismiss()
                }
            }
        }
    }
    #else
    private var macBody: some View {
        NavigationStack {
            List {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Choose from Photos…", systemImage: "photo.on.rectangle")
                }
                Button { showImporter = true } label: { Label("Choose File…", systemImage: "doc") }
                if let importError {
                    Label(importError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add File")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .platformSheet()
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: PetFileImport.allowedTypes) { result in
            switch result {
            case .success(let url): Task { await importFile(url) }
            case .failure(let error): importError = error.localizedDescription
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let jpeg = PlatformImage(data: data)?.jpegData(compressionQuality: 0.8) else {
                importError = "The photo couldn't be read."
                return
            }
            try await onPick(jpeg, "jpg")
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }

    private func importFile(_ url: URL) async {
        do {
            let payload = try PetFileImport.payload(for: url)
            try await onPick(payload.data, payload.ext)
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }
    #endif
}

#if os(iOS)
// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .data])
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { return }
            onPick(data)
        }
    }
}

// MARK: - Scanner

struct ScannerView: UIViewControllerRepresentable {
    var onScan: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (Data) -> Void
        init(onScan: @escaping (Data) -> Void) { self.onScan = onScan }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: CGSize(width: 612, height: 792)))
            let data = renderer.pdfData { ctx in
                for i in 0..<scan.pageCount {
                    ctx.beginPage()
                    scan.imageOfPage(at: i).draw(in: CGRect(origin: .zero, size: CGSize(width: 612, height: 792)))
                }
            }
            onScan(data)
            controller.dismiss(animated: true)
        }
    }
}
#endif
