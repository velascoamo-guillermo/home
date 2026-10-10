#if os(macOS)
enum PetTab: String, CaseIterable, Identifiable {
    case vet, appointments, history, events, weight, files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vet:          "Vet"
        case .appointments: "Appointments"
        case .history:      "History"
        case .events:       "Events"
        case .weight:       "Weight"
        case .files:        "Files"
        }
    }
}
#endif
