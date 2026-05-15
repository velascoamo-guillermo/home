import Testing
import Foundation
@testable import Home

@Suite("DataStore") struct DataStoreTests {

    @Test("saves and reloads AppData from disk")
    func saveAndReload() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = DataStore(directory: dir)
        let pet = Pet(name: "Luna", type: "Dog", breed: "Golden")
        store.data.pets = [pet]
        store.save()

        let reloaded = DataStore(directory: dir)
        #expect(reloaded.data.pets.count == 1)
        #expect(reloaded.data.pets[0].name == "Luna")
    }

    @Test("appointments(for:) filters by petId")
    func appointmentsFilter() {
        let store = DataStore(directory: FileManager.default.temporaryDirectory)
        let petA = UUID()
        let petB = UUID()
        store.data.appointments = [
            Appointment(petId: petA, date: .now, reason: "checkup", notes: "", status: .upcoming),
            Appointment(petId: petB, date: .now, reason: "vaccine", notes: "", status: .upcoming)
        ]
        #expect(store.appointments(for: petA).count == 1)
        #expect(store.appointments(for: petA)[0].reason == "checkup")
    }

    @Test("saveFile writes data to PetFiles directory")
    func saveFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = DataStore(directory: dir)
        let petId = UUID()
        let data = Data("fake-image".utf8)
        let file = try store.saveFile(data: data, ext: "jpg", petId: petId, linkedTo: .standalone)
        #expect(store.data.files.count == 1)
        let url = store.fileURL(for: file)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("deleteFile removes from disk and data")
    func deleteFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = DataStore(directory: dir)
        let petId = UUID()
        let file = try store.saveFile(data: Data("x".utf8), ext: "jpg", petId: petId, linkedTo: .standalone)
        store.deleteFile(file)
        #expect(store.data.files.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL(for: file).path))
    }
}
