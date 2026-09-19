import Testing
import Foundation
@testable import Casita

@Suite("ProductDeleteDialog") @MainActor struct StockDeleteDialogTests {

    @Test("deleteMessage with 0 tasks shows irrevocable warning")
    func deleteMessageZeroTasks() {
        let message = ProductDeleteDialog.deleteMessage(taskCount: 0)
        #expect(message == "This can't be undone.")
    }

    @Test("deleteMessage with 1 task shows singular linked wording")
    func deleteMessageOneTask() {
        let message = ProductDeleteDialog.deleteMessage(taskCount: 1)
        #expect(message == "Unlinks 1 task pointing at it.")
    }

    @Test("deleteMessage with 2 tasks shows plural linked wording")
    func deleteMessageTwoTasks() {
        let message = ProductDeleteDialog.deleteMessage(taskCount: 2)
        #expect(message == "Unlinks 2 tasks pointing at it.")
    }

    @Test("deleteMessage with 5 tasks shows plural linked wording")
    func deleteMessageFiveTasks() {
        let message = ProductDeleteDialog.deleteMessage(taskCount: 5)
        #expect(message == "Unlinks 5 tasks pointing at it.")
    }
}
