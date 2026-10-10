#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("PetFileImporter") @MainActor struct PetFileImporterTests {

    private func tempFile(_ name: String, _ bytes: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try bytes.write(to: url)
        return url
    }

    @Test("no failures, no message")
    func noMessage() {
        #expect(PetFileImporter.message(for: []) == nil)
    }

    @Test("a failure that already names the file is shown as is; others are prefixed with the name")
    func messages() {
        let unsupported = PetFileImporter.Failure(name: "records.zip",
                                                  reason: PetFileImport.Failure.unsupportedType("records.zip").localizedDescription)
        let offline = PetFileImporter.Failure(name: "xray.jpg", reason: SyncError.requiresConnection.localizedDescription)
        #expect(PetFileImporter.message(for: [unsupported]) == "records.zip isn't a PDF or an image.")
        #expect(PetFileImporter.message(for: [unsupported, offline])
                == "records.zip isn't a PDF or an image.\nxray.jpg: This action requires an internet connection.")
    }

    @Test("every file is attempted: an unsupported one fails by name and does not stop the next")
    func attemptsEveryFile() async throws {
        let store = SupabaseStore.makeTest()
        let zip = try tempFile("records.zip", Data([0x50, 0x4B, 0x03, 0x04]))
        let pdf = try tempFile("report.pdf", Data("%PDF-1.4\n".utf8))
        let failures = await PetFileImporter.importFiles([zip, pdf], petID: UUID(), into: store)
        #expect(failures.map(\.name) == ["records.zip", "report.pdf"])
        #expect(failures.first?.reason == "records.zip isn't a PDF or an image.")
        #expect(store.files.isEmpty)
    }
}
#endif
