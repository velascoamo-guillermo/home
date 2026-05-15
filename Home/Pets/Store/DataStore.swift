import Foundation
import Observation

@Observable
final class DataStore {
    var data: AppData

    private let jsonURL: URL
    private let filesDir: URL

    convenience init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.init(directory: documents)
    }

    init(directory: URL) {
        self.jsonURL = directory.appendingPathComponent("AppData.json")
        self.filesDir = directory.appendingPathComponent("PetFiles")
        if let saved = try? Data(contentsOf: jsonURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: saved) {
            self.data = decoded
        } else {
            self.data = AppData()
        }
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: jsonURL, options: .atomic)
    }

    // MARK: - Filtered accessors

    func appointments(for petId: UUID) -> [Appointment] {
        data.appointments.filter { $0.petId == petId }
    }

    func clinicalEntries(for petId: UUID) -> [ClinicalEntry] {
        data.clinicalEntries.filter { $0.petId == petId }.sorted { $0.date > $1.date }
    }

    func events(for petId: UUID) -> [PetEvent] {
        data.events.filter { $0.petId == petId }.sorted { $0.date > $1.date }
    }

    func files(for petId: UUID, linkedTo link: FileLink? = nil) -> [PetFile] {
        data.files.filter { f in
            guard f.petId == petId else { return false }
            guard let link else { return true }
            return f.linkedTo == link
        }
    }

    func fileURL(for file: PetFile) -> URL {
        filesDir.appendingPathComponent(file.filename)
    }

    // MARK: - File operations

    @discardableResult
    func saveFile(data fileData: Data, ext: String, petId: UUID, linkedTo: FileLink) throws -> PetFile {
        let filename = "\(UUID().uuidString).\(ext)"
        let url = filesDir.appendingPathComponent(filename)
        try fileData.write(to: url, options: .atomic)
        let source: FileSourceType = ext == "pdf" ? .document : .photo
        let file = PetFile(petId: petId, filename: filename, sourceType: source, createdAt: .now, linkedTo: linkedTo)
        data.files.append(file)
        save()
        return file
    }

    func deleteFile(_ file: PetFile) {
        try? FileManager.default.removeItem(at: fileURL(for: file))
        data.files.removeAll { $0.id == file.id }
        // Clean up stale fileId references in clinical entries and events
        for i in data.clinicalEntries.indices {
            data.clinicalEntries[i].fileIds.removeAll { $0 == file.id }
        }
        for i in data.events.indices {
            data.events[i].fileIds.removeAll { $0 == file.id }
        }
        save()
    }
}
