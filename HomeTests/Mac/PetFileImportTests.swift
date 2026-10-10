#if os(macOS)
import Testing
import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import Casita

@Suite("PetFileImport") @MainActor struct PetFileImportTests {

    private func tempFile(_ name: String, contents: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url)
        return url
    }

    private func pngData(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test("a PDF passes through byte for byte as .pdf")
    func pdfPassesThrough() throws {
        let bytes = Data("%PDF-1.4\n%fixture\n".utf8)
        let payload = try PetFileImport.payload(for: tempFile("report.pdf", contents: bytes))
        #expect(payload.ext == "pdf")
        #expect(payload.data == bytes)
    }

    @Test("an image is re-encoded as a decodable JPEG")
    func imageBecomesJPEG() throws {
        let payload = try PetFileImport.payload(for: tempFile("xray.png", contents: pngData(width: 40, height: 20)))
        #expect(payload.ext == "jpg")
        let decoded = try #require(NSImage(data: payload.data))
        #expect(decoded.size == CGSize(width: 40, height: 20))
    }

    @Test("a zip archive is rejected by name")
    func zipRejected() throws {
        let url = try tempFile("records.zip", contents: Data([0x50, 0x4B, 0x03, 0x04]))
        #expect(throws: PetFileImport.Failure.unsupportedType("records.zip")) {
            try PetFileImport.payload(for: url)
        }
    }

    @Test("a folder is rejected")
    func folderRejected() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Vet Records-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #expect(throws: PetFileImport.Failure.unsupportedType(dir.lastPathComponent)) {
            try PetFileImport.payload(for: dir)
        }
    }

    @Test("a file with an image extension but garbage bytes is unreadable")
    func corruptImageUnreadable() throws {
        let url = try tempFile("broken.jpg", contents: Data("not an image".utf8))
        #expect(throws: PetFileImport.Failure.unreadable("broken.jpg")) {
            try PetFileImport.payload(for: url)
        }
    }
}
#endif
