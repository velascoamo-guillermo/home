import Foundation

enum Weekday: Int, CaseIterable, Identifiable, Hashable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .monday:    return "Lunes"
        case .tuesday:   return "Martes"
        case .wednesday: return "Miércoles"
        case .thursday:  return "Jueves"
        case .friday:    return "Viernes"
        case .saturday:  return "Sábado"
        case .sunday:    return "Domingo"
        }
    }
}
