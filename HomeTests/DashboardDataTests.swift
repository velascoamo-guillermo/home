import Testing
import Foundation
@testable import Home

@Suite("DashboardData") @MainActor struct DashboardDataTests {

    private let day: TimeInterval = 86_400

    private func task(_ title: String, due: Date) -> HouseholdTask {
        HouseholdTask(title: title, icon: "x", intervalDays: 7, nextDueDate: due)
    }
    private func pet(_ name: String) -> Pet { Pet(name: name, type: "Dog", breed: "Lab") }
    private func stock(_ name: String, packages: Int, loose: Int) -> StockProduct {
        StockProduct(name: name, icon: "x", packages: packages, looseUnits: loose, unitsPerPackage: 6)
    }
    private func meal(_ title: String, day: Int, slot: MealSlot) -> Meal {
        Meal(dayOfWeek: day, slot: slot, title: title)
    }
    private func appt(_ reason: String, date: Date, status: AppointmentStatus, petId: UUID) -> Appointment {
        Appointment(petId: petId, date: date, reason: reason, notes: "", status: status)
    }
    private func event(date: Date, petId: UUID) -> PetEvent {
        PetEvent(petId: petId, date: date, title: "W", category: .weight, notes: "", value: nil)
    }

    @Test("upcomingTasks merges tasks + future events, sorts by due, applies limit")
    func tasksMergeSortLimit() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let p = pet("Cacao")
        let tasks = [task("Late", due: now + 3 * day), task("Soon", due: now + 1 * day)]
        let pastEvent = event(date: now - 5 * day, petId: p.id)
        let futureEvent = event(date: now + 2 * day, petId: p.id)
        let items = DashboardData.upcomingTasks(
            tasks: tasks, events: [pastEvent, futureEvent], pets: [p], today: now, limit: 2
        )
        // Sorted: Soon(+1), futureEvent(+2), Late(+3) -> limited to 2. Past event dropped.
        #expect(items.count == 2)
        #expect(items.map(\.id) == [tasks[1].id, futureEvent.id])
    }

    @Test("shoppingList keeps only zero-unit products, reports total + limited items")
    func shopping() {
        let s = [stock("Milk", packages: 0, loose: 0),
                 stock("Eggs", packages: 1, loose: 0),
                 stock("Bread", packages: 0, loose: 0),
                 stock("Rice", packages: 0, loose: 0)]
        let r = DashboardData.shoppingList(stock: s, limit: 2)
        #expect(r.total == 3)
        #expect(r.items.map(\.name) == ["Milk", "Bread"])
    }

    @Test("weekMeals drops empty titles and rotates to start at today")
    func meals() {
        let m = [meal("Mon lunch", day: 1, slot: .lunch),
                 meal("", day: 2, slot: .lunch),               // dropped: empty
                 meal("Wed dinner", day: 3, slot: .dinner),
                 meal("Fri lunch", day: 5, slot: .lunch)]
        // today = Wednesday (3): order should be Wed, Fri, then wrap to Mon.
        let r = DashboardData.weekMeals(meals: m, todayWeekday: 3, limit: 5)
        #expect(r.map(\.title) == ["Wed dinner", "Fri lunch", "Mon lunch"])
    }

    @Test("upcomingAppointments filters to upcoming, pairs pet, sorts, limits")
    func appointments() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let p = pet("Rex")
        let a1 = appt("Vacuna", date: now + 2 * day, status: .upcoming, petId: p.id)
        let a2 = appt("Checkup", date: now + 1 * day, status: .upcoming, petId: p.id)
        let done = appt("Old", date: now - day, status: .done, petId: p.id)
        let items = DashboardData.upcomingAppointments(
            appointments: [a1, a2, done], pets: [p], limit: 5
        )
        #expect(items.map(\.id) == [a2.id, a1.id])
    }
}
