import Foundation

struct Veterinarian: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var clinicName: String
    var phone: String
    var address: String
    var notes: String
}
