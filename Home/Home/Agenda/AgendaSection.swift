import Foundation

enum AgendaSection: Int, CaseIterable, Comparable {
    case overdue, allDay, anytime, morning, afternoon, evening

    var title: String {
        switch self {
        case .overdue:   "Overdue"
        case .allDay:    "All-day"
        case .anytime:   "Anytime"
        case .morning:   "Morning"
        case .afternoon: "Afternoon"
        case .evening:   "Evening"
        }
    }

    static func < (lhs: AgendaSection, rhs: AgendaSection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func timeBucket(hour: Int) -> AgendaSection {
        switch hour {
        case ..<12: .morning
        case ..<18: .afternoon
        default:    .evening
        }
    }
}
