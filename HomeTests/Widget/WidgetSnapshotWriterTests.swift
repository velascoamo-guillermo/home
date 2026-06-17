import Testing
import Foundation
@testable import Home

struct WidgetSnapshotWriterTests {

    // MARK: - todayWeekday

    @Test func sundayMapsTo7() {
        // 2026-06-14 is a Sunday
        let result = WidgetSnapshotWriter.todayWeekday(
            calendar: .current,
            date: makeDate(year: 2026, month: 6, day: 14)
        )
        #expect(result == 7)
    }

    @Test func mondayMapsTo1() {
        // 2026-06-15 is a Monday
        let result = WidgetSnapshotWriter.todayWeekday(
            calendar: .current,
            date: makeDate(year: 2026, month: 6, day: 15)
        )
        #expect(result == 1)
    }

    @Test func saturdayMapsTo6() {
        // 2026-06-13 is a Saturday
        let result = WidgetSnapshotWriter.todayWeekday(
            calendar: .current,
            date: makeDate(year: 2026, month: 6, day: 13)
        )
        #expect(result == 6)
    }

    // MARK: - buildSnapshot – events

    @Test func eventsAreCappedAtThree() {
        let items: [HomeItem] = (0..<5).map { i in
            let appt = Appointment(petId: UUID(), date: .now.addingTimeInterval(Double(i) * 3600),
                                   reason: "Visit \(i)", notes: "", status: .upcoming)
            let pet = Pet(name: "Pet \(i)", type: "dog", breed: "Lab")
            return .appointment(appt, pet)
        }
        let snapshot = WidgetSnapshotWriter.buildSnapshot(
            timeline: items, stockProducts: [], lunch: nil, dinner: nil
        )
        #expect(snapshot.events.count == 3)
    }

    @Test func appointmentEventMapsCorrectly() {
        let eventDate = Date(timeIntervalSince1970: 1_800_000_000)
        let appt = Appointment(petId: UUID(), date: eventDate,
                               reason: "Vacunas", notes: "", status: .upcoming)
        let pet = Pet(name: "Rex", type: "dog", breed: "Labrador")
        let items: [HomeItem] = [.appointment(appt, pet)]

        let snapshot = WidgetSnapshotWriter.buildSnapshot(
            timeline: items, stockProducts: [], lunch: nil, dinner: nil
        )

        #expect(snapshot.events.count == 1)
        let event = snapshot.events[0]
        #expect(event.title == "Vacunas")
        #expect(event.subtitle == "Rex")
        #expect(event.date == eventDate)
        #expect(event.kind == .appointment)
        #expect(event.systemImage == "calendar")
    }

    @Test func taskEventUsesNotesAsSubtitle() {
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let task = HouseholdTask(
            title: "Cambiar filtro",
            icon: "drop",
            intervalDays: 30,
            nextDueDate: dueDate,
            notes: "Filtro cocina"
        )
        let items: [HomeItem] = [.task(task)]

        let snapshot = WidgetSnapshotWriter.buildSnapshot(
            timeline: items, stockProducts: [], lunch: nil, dinner: nil
        )

        #expect(snapshot.events[0].subtitle == "Filtro cocina")
        #expect(snapshot.events[0].systemImage == "drop")
        #expect(snapshot.events[0].kind == .task)
    }

    @Test func taskEventWithProductAppendsSuffix() {
        let productId = UUID()
        let task = HouseholdTask(
            title: "Reponer sal",
            icon: "shaker",
            intervalDays: 7,
            nextDueDate: .now,
            notes: "",
            productId: productId,
            quantityPerCompletion: 2
        )
        let product = StockProduct(
            id: productId, name: "Sal gruesa", icon: "shaker",
            packages: 1, looseUnits: 0, unitsPerPackage: 5
        )
        let items: [HomeItem] = [.task(task)]

        let snapshot = WidgetSnapshotWriter.buildSnapshot(
            timeline: items, stockProducts: [product], lunch: nil, dinner: nil
        )

        let subtitle = snapshot.events[0].subtitle
        #expect(subtitle.contains("Sal gruesa"))
        #expect(subtitle.contains("× 2"))
    }

    // MARK: - buildSnapshot – meals

    @Test func nilMealEntryProducesEmptyWidgetMeal() {
        let snapshot = WidgetSnapshotWriter.buildSnapshot(
            timeline: [], stockProducts: [], lunch: nil, dinner: nil
        )
        #expect(snapshot.lunch.isEmpty == true)
        #expect(snapshot.lunch.slot == "lunch")
        #expect(snapshot.dinner.isEmpty == true)
        #expect(snapshot.dinner.slot == "dinner")
    }

    @Test func presentMealEntryMapsCorrectly() {
        let meal = Meal(dayOfWeek: 1, slot: .lunch, title: "Pasta carbonara")
        let productId = UUID()
        let product = StockProduct(
            id: productId, name: "Panceta", icon: "cart",
            packages: 1, looseUnits: 0, unitsPerPackage: 1
        )
        let link = MealEntry.Link(product: product, quantity: 1)
        let entry = MealEntry(meal: meal, links: [link])

        let snapshot = WidgetSnapshotWriter.buildSnapshot(
            timeline: [], stockProducts: [], lunch: entry, dinner: nil
        )

        #expect(snapshot.lunch.isEmpty == false)
        #expect(snapshot.lunch.title == "Pasta carbonara")
        #expect(snapshot.lunch.products == ["Panceta"])
        #expect(snapshot.lunch.isShort == false)
    }

    @Test func isShortPropagates() {
        let meal = Meal(dayOfWeek: 1, slot: .dinner, title: "Paella")
        let product = StockProduct(
            name: "Arroz", icon: "cart",
            packages: 0, looseUnits: 0, unitsPerPackage: 1  // totalUnits = 0
        )
        let link = MealEntry.Link(product: product, quantity: 2)  // needs 2, has 0
        let entry = MealEntry(meal: meal, links: [link])

        let snapshot = WidgetSnapshotWriter.buildSnapshot(
            timeline: [], stockProducts: [], lunch: nil, dinner: entry
        )

        #expect(snapshot.dinner.isShort == true)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
