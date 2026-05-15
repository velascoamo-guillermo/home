import Foundation

struct Pet: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: String
    var breed: String
    var photoFilename: String? = nil
}
