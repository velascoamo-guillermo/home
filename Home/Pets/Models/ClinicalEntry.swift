import Foundation

struct ClinicalEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var title: String
    var description: String
    var fileIds: [UUID]
}
