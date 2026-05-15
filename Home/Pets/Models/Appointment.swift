import Foundation

enum AppointmentStatus: String, Codable, CaseIterable {
    case upcoming, done, cancelled
}

struct Appointment: Codable, Identifiable {
    var id: UUID = UUID()
    var petId: UUID
    var date: Date
    var reason: String
    var notes: String
    var status: AppointmentStatus
}
