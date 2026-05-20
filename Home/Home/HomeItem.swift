import Foundation

enum HomeItem: Identifiable {
    case appointment(Appointment, Pet)
    case task(HouseholdTask)

    var id: UUID {
        switch self {
        case .appointment(let a, _): return a.id
        case .task(let t):           return t.id
        }
    }

    var dueDate: Date {
        switch self {
        case .appointment(let a, _): return a.date
        case .task(let t):           return t.nextDueDate
        }
    }
}
