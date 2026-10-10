#if os(macOS)
import AppKit
import Foundation
import UniformTypeIdentifiers

enum PetFileImport {
    enum Failure: LocalizedError, Equatable {
        case unsupportedType(String)
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedType(let name): "\(name) isn't a PDF or an image."
            case .unreadable(let name):      "\(name) couldn't be read."
            }
        }
    }

    static let allowedTypes: [UTType] = [.pdf, .image]

    /// Turns a chosen or dropped file into the `(data, ext)` pair `SupabaseStore.uploadFile`
    /// expects: PDFs pass through, images are re-encoded as JPEG, anything else is rejected.
    nonisolated static func payload(for url: URL) throws -> (data: Data, ext: String) {
        let name = url.lastPathComponent
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        guard let type, type.conforms(to: .pdf) || type.conforms(to: .image) else {
            throw Failure.unsupportedType(name)
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable(name) }
        if type.conforms(to: .pdf) { return (data, "pdf") }
        guard let image = NSImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.8) else {
            throw Failure.unreadable(name)
        }
        return (jpeg, "jpg")
    }
}
#endif
