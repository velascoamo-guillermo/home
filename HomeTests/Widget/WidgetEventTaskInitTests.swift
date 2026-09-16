import Testing
import Foundation
@testable import Casita

struct WidgetEventTaskInitTests {

    @Test func emptyNotesUsesFormattedDueDate() {
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let task = HouseholdTask(
            title: "Cambiar filtro",
            intervalDays: 30,
            nextDueDate: dueDate,
            notes: ""
        )

        let event = WidgetEvent(task: task, productName: nil)

        #expect(event.subtitle == dueDate.formatted(date: .abbreviated, time: .omitted))
        #expect(event.id == task.id)
        #expect(event.title == task.title)
        #expect(event.date == dueDate)
        #expect(event.kind == .task)
    }

    @Test func nonEmptyNotesUsedAsSubtitle() {
        let task = HouseholdTask(
            title: "Cambiar filtro",
            intervalDays: 30,
            nextDueDate: .now,
            notes: "Filtro cocina"
        )

        let event = WidgetEvent(task: task, productName: nil)

        #expect(event.subtitle == "Filtro cocina")
    }

    @Test func productNameAppendsWithoutQuantity() {
        let task = HouseholdTask(
            title: "Reponer sal",
            intervalDays: 7,
            nextDueDate: .now,
            notes: "Cocina",
            productId: UUID(),
            quantityPerCompletion: 2
        )

        let event = WidgetEvent(task: task, productName: "Sal gruesa")

        #expect(event.subtitle == "Cocina · Sal gruesa")
    }

    @Test func nilProductNameOmitsSuffixEvenWithProductId() {
        let task = HouseholdTask(
            title: "Reponer sal",
            intervalDays: 7,
            nextDueDate: .now,
            notes: "Cocina",
            productId: UUID(),
            quantityPerCompletion: 2
        )

        let event = WidgetEvent(task: task, productName: nil)

        #expect(event.subtitle == "Cocina")
    }
}
