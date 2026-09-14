import Foundation

enum Weekday: Int, CaseIterable, Identifiable, Hashable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    /// Maps `Calendar.weekday` (1 = Sunday) onto ISO numbering (1 = Monday).
    init(date: Date, calendar: Calendar) {
        let weekday = calendar.component(.weekday, from: date)
        self = Weekday(rawValue: (weekday + 5) % 7 + 1) ?? .monday
    }

    var initial: String {
        switch self {
        case .monday:    "L"
        case .tuesday:   "M"
        case .wednesday: "X"
        case .thursday:  "J"
        case .friday:    "V"
        case .saturday:  "S"
        case .sunday:    "D"
        }
    }

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
