import Foundation

struct AppData: Codable {
    var veterinarian: Veterinarian? = nil
    var pets: [Pet] = []
    var appointments: [Appointment] = []
    var clinicalEntries: [ClinicalEntry] = []
    var events: [PetEvent] = []
    var files: [PetFile] = []
}
