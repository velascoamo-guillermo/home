import Foundation

enum AgendaItem: Identifiable, Hashable {
    case task(HouseholdTask, TaskOccurrence)
    case appointment(Appointment, Pet)
    case petEvent(PetEvent, Pet)
    case meal(Meal, MealSlot)
    case calendarEvent(CalendarEventSnapshot, continuesFromPreviousDay: Bool)

    var id: String {
        switch self {
        case .task(let t, _):          "task-\(t.id)"
        case .appointment(let a, _):   "appointment-\(a.id)"
        case .petEvent(let e, _):      "petEvent-\(e.id)"
        case .meal(let m, let slot):   "meal-\(m.id)-\(slot.rawValue)"
        case .calendarEvent(let e, _): "calendar-\(e.id)"
        }
    }

    var title: String {
        switch self {
        case .task(let t, _):          t.title
        case .appointment(let a, _):   a.reason
        case .petEvent(let e, _):      e.title
        case .meal(let m, _):          m.title
        case .calendarEvent(let e, _): e.title
        }
    }
}
