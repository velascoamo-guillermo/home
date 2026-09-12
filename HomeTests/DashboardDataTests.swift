import Testing
import Foundation
@testable import Casita

@Suite("DashboardData") @MainActor struct DashboardDataTests {

    private let day: TimeInterval = 86_400

    private func task(_ title: String, due: Date) -> HouseholdTask {
        HouseholdTask(title: title, icon: "x", intervalDays: 7, nextDueDate: due)
    }
    private func pet(_ name: String) -> Pet { Pet(name: name, type: "Dog", breed: "Lab") }
    private func stock(_ name: String, packages: Int, loose: Int, needed: Bool = false) -> StockProduct {
        StockProduct(name: name, icon: "x", packages: packages, looseUnits: loose,
                     unitsPerPackage: 6, needed: needed)
    }
    private func planned(day: Int, slot: MealSlot, title: String) -> (MenuEntry, Meal) {
        let meal = Meal(title: title)
        return (MenuEntry(dayOfWeek: day, slot: slot, mealId: meal.id), meal)
    }
    private func appt(_ reason: String, date: Date, status: AppointmentStatus, petId: UUID) -> Appointment {
        Appointment(petId: petId, date: date, reason: reason, notes: "", status: status)
    }
    private func event(date: Date, petId: UUID) -> PetEvent {
        PetEvent(petId: petId, date: date, title: "W", category: .weight, notes: "", value: nil)
    }

    @Test("upcomingTasks merges tasks + future events, sorts by due, applies limit, reports total")
    func tasksMergeSortLimit() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let p = pet("Cacao")
        let tasks = [task("Late", due: now + 3 * day), task("Soon", due: now + 1 * day)]
        let pastEvent = event(date: now - 5 * day, petId: p.id)
        let futureEvent = event(date: now + 2 * day, petId: p.id)
        let r = DashboardData.upcomingTasks(
            tasks: tasks, events: [pastEvent, futureEvent], pets: [p], today: now, limit: 2
        )
        // Sorted: Soon(+1), futureEvent(+2), Late(+3) -> limited to 2. Past event dropped.
        #expect(r.items.count == 2)
        #expect(r.items.map(\.id) == [tasks[1].id, futureEvent.id])
        #expect(r.total == 3)
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

    @Test("shoppingList includes needed-with-stock products alongside zero-unit ones")
    func shoppingIncludesNeededWithStock() {
        let s = [stock("Milk", packages: 0, loose: 0),
                 stock("Eggs", packages: 1, loose: 0, needed: true),
                 stock("Rice", packages: 2, loose: 0)]
        let r = DashboardData.shoppingList(stock: s, limit: 5)
        #expect(r.total == 2)
        #expect(r.items.map(\.name) == ["Milk", "Eggs"])
    }

    @Test("weekMeals drops empty titles and rotates to start at today")
    func meals() {
        let pairs = [planned(day: 1, slot: .lunch, title: "Mon lunch"),
                     planned(day: 2, slot: .lunch, title: ""),               // dropped: empty
                     planned(day: 3, slot: .dinner, title: "Wed dinner"),
                     planned(day: 5, slot: .lunch, title: "Fri lunch")]
        let entries = pairs.map(\.0)
        let meals = pairs.map(\.1)
        // today = Wednesday (3): order should be Wed, Fri, then wrap to Mon.
        let r = DashboardData.weekMeals(entries: entries, meals: meals,
                                        todayWeekday: 3, limit: 5)
        #expect(r.items.map(\.meal.title) == ["Wed dinner", "Fri lunch", "Mon lunch"])
        #expect(r.total == 3)
    }

    @Test("weekMeals collapses duplicate (day, slot) entries, keeping the newest updatedAt")
    func mealsCollapsesDuplicateSlot() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let meal = Meal(title: "Mon lunch")
        let older = MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: meal.id, updatedAt: now)
        let newer = MenuEntry(dayOfWeek: 1, slot: .lunch, mealId: meal.id, updatedAt: now + day)
        let r = DashboardData.weekMeals(entries: [older, newer], meals: [meal],
                                        todayWeekday: 1, limit: 5)
        #expect(r.items.count == 1)
        #expect(r.items.first?.entry.id == newer.id)
        #expect(r.total == 1)
    }

    @Test("weekMeals reports total beyond limit")
    func mealsOverflow() {
        let pairs = [planned(day: 1, slot: .lunch, title: "A"),
                     planned(day: 2, slot: .lunch, title: "B"),
                     planned(day: 3, slot: .lunch, title: "C")]
        let entries = pairs.map(\.0)
        let meals = pairs.map(\.1)
        let r = DashboardData.weekMeals(entries: entries, meals: meals,
                                        todayWeekday: 1, limit: 2)
        #expect(r.items.count == 2)
        #expect(r.total == 3)
    }

    @Test("upcomingAppointments filters to upcoming, pairs pet, sorts, limits, reports total")
    func appointments() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let p = pet("Rex")
        let a1 = appt("Vacuna", date: now + 2 * day, status: .upcoming, petId: p.id)
        let a2 = appt("Checkup", date: now + 1 * day, status: .upcoming, petId: p.id)
        let a3 = appt("Dental", date: now + 3 * day, status: .upcoming, petId: p.id)
        let done = appt("Old", date: now - day, status: .done, petId: p.id)
        let r = DashboardData.upcomingAppointments(
            appointments: [a1, a2, a3, done], pets: [p], limit: 2
        )
        #expect(r.items.map(\.id) == [a2.id, a1.id])
        #expect(r.total == 3)
    }
}
