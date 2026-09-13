import Foundation

struct AgendaInput {
    var tasks: [HouseholdTask] = []
    var appointments: [Appointment] = []
    var petEvents: [PetEvent] = []
    var pets: [Pet] = []
    var menuEntries: [MenuEntry] = []
    var meals: [Meal] = []
    var calendarEvents: [CalendarEventSnapshot] = []
}
