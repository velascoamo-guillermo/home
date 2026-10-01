#if os(macOS)
import Foundation
import Observation

/// Per-window state the menu bar reaches through `FocusedValues.macWindow`.
@Observable
final class MacWindowModel {
    var selection: SidebarItem {
        didSet { if selection != oldValue { availableCommands = [] } }
    }
    var pendingAction: MacPendingAction?
    var isInspectorPresented = false
    var budgetMonth = BudgetMonth(date: .now, calendar: .current)
    var searchText = ""
    var isSearchFocused = false
    /// Written by the visible feature view: which File-menu feature commands it can run right now.
    var availableCommands: Set<MacFeatureCommand> = []
    /// Set by the menu bar, consumed and cleared by the visible feature view.
    var requestedCommand: MacFeatureCommand?

    init(selection: SidebarItem) {
        self.selection = selection
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Edit ▸ Find raises `isSearchFocused`; the shell consumes it once so the next ⌘F fires again.
    func consumeSearchFocusRequest() -> Bool {
        guard isSearchFocused else { return false }
        isSearchFocused = false
        return true
    }

    func go(_ target: GoTarget, pets: [Pet]) {
        guard let destination = CommandRouter.destination(for: target, current: selection, pets: pets) else { return }
        searchText = ""
        selection = destination
    }

    func perform(_ action: MacPendingAction) {
        if let destination = CommandRouter.destination(for: action, current: selection) {
            searchText = ""
            selection = destination
        }
        pendingAction = action
    }

    func stepPeriod(by delta: Int) {
        guard PeriodNavigator.isAvailable(on: selection) else { return }
        budgetMonth = PeriodNavigator.step(budgetMonth, by: delta)
    }

    func toggleInspector() {
        guard CommandRouter.hasInspector(on: selection) else { return }
        isInspectorPresented.toggle()
    }

    func request(_ command: MacFeatureCommand) {
        guard availableCommands.contains(command) else { return }
        requestedCommand = command
    }
}
#endif
