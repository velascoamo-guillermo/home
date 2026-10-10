#if os(macOS)
import Testing
import Foundation
import AppKit
@testable import Casita

@Suite("Mac pet detail") @MainActor struct MacPetDetailTests {

    @Test("all six iPhone sections, including Weight, in the iPhone's order")
    func tabs() {
        #expect(PetTab.allCases.map(\.title) == ["Vet", "Appointments", "History", "Events", "Weight", "Files"])
        #expect(PetTab(rawValue: "weight") == .weight)
    }

    @Test("a picked photo becomes a JPEG no larger than 512 points")
    func thumbnail() async throws {
        let context = try #require(CGContext(
            data: nil, width: 2000, height: 1000, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        let image = NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 2000, height: 1000))
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let png = try #require(NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]))
        let jpeg = try #require(await MacPetDetailView.thumbnail(from: png))
        #expect(try #require(NSImage(data: jpeg)).size == CGSize(width: 512, height: 256))
    }

    @Test("garbage bytes produce no thumbnail")
    func thumbnailRejectsGarbage() async {
        #expect(await MacPetDetailView.thumbnail(from: Data("nope".utf8)) == nil)
    }

    @Test("pet actions stay on the pet and only Import is not a sheet")
    func petActions() {
        let id = UUID()
        #expect(CommandRouter.destination(for: .newAppointment(petID: id), current: .pet(id)) == nil)
        #expect(CommandRouter.destination(for: .importFiles(petID: id), current: .pet(id)) == nil)
        #expect(MacPendingAction.newAppointment(petID: id).presentsSheet)
        #expect(MacPendingAction.newPetEvent(petID: id).presentsSheet)
        #expect(!MacPendingAction.importFiles(petID: id).presentsSheet)
        #expect(MacPendingAction.importFiles(petID: id).title == "Import…")
    }

    @Test("the importer shows only for its own pet, and dismissing it clears pendingAction")
    func importBindingClearsPendingAction() {
        let id = UUID()
        let model = MacWindowModel(selection: .pet(id))
        model.perform(.importFiles(petID: id))
        #expect(MacPetDetailView.importBinding(for: UUID(), model: model).wrappedValue == false)

        let binding = MacPetDetailView.importBinding(for: id, model: model)
        #expect(binding.wrappedValue)
        binding.wrappedValue = false
        #expect(model.pendingAction == nil)
    }

    @Test("cancelling the importer shows no alert; real errors do")
    func importFailureMessage() {
        #expect(MacPetDetailView.importFailureMessage(for: CocoaError(.userCancelled)) == nil)
        #expect(MacPetDetailView.importFailureMessage(for: CocoaError(.fileReadNoPermission)) != nil)
    }
}
#endif
