#if os(macOS)
import Testing
import Foundation
@testable import Casita

@Suite("MacWindowModel") @MainActor struct MacWindowModelTests {
    private let luna = Pet(name: "Luna", type: "Dog", breed: "Golden")

    @Test("File ▸ New Expense from Tasks switches to Budget and queues the sheet")
    func performNew() {
        let model = MacWindowModel(selection: .tasks)
        model.perform(.newExpense)
        #expect(model.selection == .budget)
        #expect(model.pendingAction == .newExpense)
    }

    @Test("New Pet keeps the current selection")
    func performNewPet() {
        let model = MacWindowModel(selection: .stock)
        model.perform(.newPet)
        #expect(model.selection == .stock)
        #expect(model.pendingAction == .newPet)
    }

    @Test("Go clears an active search so the chosen feature is visible")
    func goClearsSearch() {
        let model = MacWindowModel(selection: .today)
        model.searchText = "milk"
        model.go(.stock, pets: [])
        #expect(model.selection == .stock)
        #expect(model.searchText.isEmpty)
    }

    @Test("Go ▸ Pets without pets changes nothing")
    func goPetsWithoutPets() {
        let model = MacWindowModel(selection: .meals)
        model.go(.pets, pets: [])
        #expect(model.selection == .meals)
        model.go(.pets, pets: [luna])
        #expect(model.selection == .pet(luna.id))
    }

    @Test("period steps move the budget month only on Budget")
    func periodSteps() {
        let model = MacWindowModel(selection: .tasks)
        let start = model.budgetMonth
        model.stepPeriod(by: 1)
        #expect(model.budgetMonth == start)
        model.selection = .budget
        model.stepPeriod(by: 1)
        #expect(model.budgetMonth == start.next)
    }

    @Test("a feature command is only requested when the current view offers it")
    func requestGated() {
        let model = MacWindowModel(selection: .tasks)
        model.request(.markDone)
        #expect(model.requestedCommand == nil)
        model.availableCommands = [.markDone]
        model.request(.markDone)
        #expect(model.requestedCommand == .markDone)
    }

    @Test("changing feature clears commands the previous view offered")
    func selectionClearsCommands() {
        let model = MacWindowModel(selection: .tasks)
        model.availableCommands = [.markDone]
        model.selection = .budget
        #expect(model.availableCommands.isEmpty)
    }
}
#endif
