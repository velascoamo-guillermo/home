#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("CommandRouter") @MainActor struct CommandRouterTests {
    private let luna = Pet(name: "Luna", type: "Dog", breed: "Golden")
    private let alba = Pet(name: "Alba", type: "Cat", breed: "Siamese")

    @Test("Go ⌘1–⌘6 land on their fixed rows in spec order")
    func goFixed() {
        let expected: [(GoTarget, SidebarItem, String)] = [
            (.today, .today, "1"), (.tasks, .tasks, "2"), (.shopping, .shopping, "3"),
            (.stock, .stock, "4"), (.meals, .meals, "5"), (.budget, .budget, "6"),
        ]
        for (target, item, key) in expected {
            #expect(CommandRouter.destination(for: target, current: .today, pets: []) == item)
            #expect(target.keyEquivalent.character == Character(key))
        }
        #expect(GoTarget.pets.keyEquivalent.character == "7")
    }

    @Test("Go ▸ Pets opens the first pet by name, keeps a pet that is already selected, and is unavailable without pets")
    func goPets() {
        #expect(CommandRouter.destination(for: .pets, current: .tasks, pets: [luna, alba]) == .pet(alba.id))
        #expect(CommandRouter.destination(for: .pets, current: .pet(luna.id), pets: [luna, alba]) == .pet(luna.id))
        #expect(CommandRouter.destination(for: .pets, current: .pet(UUID()), pets: [luna]) == .pet(luna.id))
        #expect(CommandRouter.destination(for: .pets, current: .tasks, pets: []) == nil)
    }

    @Test("File ▸ New commands switch to the feature that shows the result")
    func newItemDestinations() {
        #expect(CommandRouter.destination(for: .newTask, current: .budget) == .tasks)
        #expect(CommandRouter.destination(for: .newExpense, current: .tasks) == .budget)
        #expect(CommandRouter.destination(for: .newShoppingItem, current: .today) == .shopping)
        #expect(CommandRouter.destination(for: .newProduct, current: .today) == .stock)
        #expect(CommandRouter.destination(for: .newMeal, current: .today) == .meals)
        #expect(CommandRouter.destination(for: .newPet, current: .budget) == nil)
    }

    @Test("the toolbar + maps to one New command per feature")
    func primaryActions() {
        #expect(CommandRouter.primaryAction(on: .today) == .newTask)
        #expect(CommandRouter.primaryAction(on: .tasks) == .newTask)
        #expect(CommandRouter.primaryAction(on: .shopping) == .newShoppingItem)
        #expect(CommandRouter.primaryAction(on: .stock) == .newProduct)
        #expect(CommandRouter.primaryAction(on: .meals) == .newMeal)
        #expect(CommandRouter.primaryAction(on: .budget) == .newExpense)
        #expect(CommandRouter.primaryAction(on: .pet(UUID())) == nil)
    }

    @Test("inspectors exist where the spec puts them")
    func inspectors() {
        #expect(CommandRouter.hasInspector(on: .today))
        #expect(CommandRouter.hasInspector(on: .tasks))
        #expect(CommandRouter.hasInspector(on: .stock))
        #expect(CommandRouter.hasInspector(on: .meals))
        #expect(CommandRouter.hasInspector(on: .budget))
        #expect(!CommandRouter.hasInspector(on: .shopping))
        #expect(!CommandRouter.hasInspector(on: .pet(UUID())))
    }

    @Test("menu titles are title-case verbs, with an ellipsis only where more input follows")
    func titles() {
        #expect(MacPendingAction.newShoppingItem.title == "New Shopping Item")
        #expect(MacPendingAction.newPet.title == "New Pet…")
        #expect(MacFeatureCommand.markDone.title == "Mark as Done")
        #expect(MacFeatureCommand.snoozeOneDay.title == "Snooze One Day")
        #expect(MacFeatureCommand.markBought.title == "Mark as Bought")
        #expect(MacFeatureCommand.finishShopping.title == "Finish Shopping")
        #expect(MacFeatureCommand.suggestWeek.title == "Suggest Week")
    }
}
#endif
