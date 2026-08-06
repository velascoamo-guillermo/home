import Testing
import Foundation
@testable import Casita

struct WidgetEventTaskInitTests {

    @Test func emptyNotesUsesFormattedDueDate() {
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let task = HouseholdTask(
            title: "Cambiar filtro",
            icon: "drop",
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
        #expect(event.systemImage == task.icon)
    }

    @Test func nonEmptyNotesUsedAsSubtitle() {
        let task = HouseholdTask(
            title: "Cambiar filtro",
            icon: "drop",
            intervalDays: 30,
            nextDueDate: .now,
            notes: "Filtro cocina"
        )

        let event = WidgetEvent(task: task, productName: nil)

        #expect(event.subtitle == "Filtro cocina")
    }

    @Test func productNameAppendsSuffix() {
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

        let event = WidgetEvent(task: task, productName: "Sal gruesa")

        #expect(event.subtitle.contains("Sal gruesa"))
        #expect(event.subtitle.contains("× 2"))
    }

    @Test func nilProductNameOmitsSuffixEvenWithProductId() {
        let task = HouseholdTask(
            title: "Reponer sal",
            icon: "shaker",
            intervalDays: 7,
            nextDueDate: .now,
            notes: "",
            productId: UUID(),
            quantityPerCompletion: 2
        )

        let event = WidgetEvent(task: task, productName: nil)

        #expect(!event.subtitle.contains("×"))
    }
}
