#if os(macOS)
import SwiftUI

struct MacAppCommands: Commands {
    let store: SupabaseStore
    let bootstrap: MacBootstrap
    @FocusedValue(\.macWindow) private var window
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()

        CommandGroup(replacing: .newItem) {
            newButton(.newTask, KeyboardShortcut("n"))
            newButton(.newExpense, KeyboardShortcut("e", modifiers: [.shift, .command]))
            newButton(.newShoppingItem, KeyboardShortcut("l", modifiers: [.shift, .command]))
            newButton(.newProduct, nil)
            newButton(.newMeal, nil)
            newButton(.newPet, nil)
            Divider()
            ForEach(MacFeatureCommand.allCases, id: \.self) { command in
                Button(command.title) { window?.request(command) }
                    .disabled(!(window?.availableCommands.contains(command) ?? false))
            }
            Divider()
            Button(window == nil ? "New Window" : "Open in New Window") {
                openWindow(value: MacWindowSeed.new(window?.selection ?? .today))
            }
        }

        CommandGroup(replacing: .textEditing) {
            Button("Find…") { window?.isSearchFocused = true }
                .keyboardShortcut("f")
                .disabled(!shellReady)
        }

        CommandGroup(after: .sidebar) {
            Button(window?.isInspectorPresented == true ? "Hide Inspector" : "Show Inspector") {
                window?.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: [.option, .command])
            .disabled(!(window.map { CommandRouter.hasInspector(on: $0.selection) } ?? false))
            Divider()
            Button("Refresh") { Task { await store.refreshFromLocal() } }
                .keyboardShortcut("r")
        }

        CommandMenu("Go") {
            ForEach(GoTarget.allCases, id: \.self) { target in
                Button(target.title) { window?.go(target, pets: store.pets) }
                    .keyboardShortcut(target.keyEquivalent)
                    .disabled(goDestination(target) == nil)
            }
            Divider()
            Button("Previous Period") { window?.stepPeriod(by: -1) }
                .keyboardShortcut("[")
                .disabled(!periodAvailable)
            Button("Next Period") { window?.stepPeriod(by: 1) }
                .keyboardShortcut("]")
                .disabled(!periodAvailable)
        }

        CommandGroup(replacing: .help) {
            Button("Casita Help") { openWindow(id: MacHelpView.windowID) }
                .keyboardShortcut("?")
        }
    }

    private func newButton(_ action: MacPendingAction, _ shortcut: KeyboardShortcut?) -> some View {
        Button(action.title) { window?.perform(action) }
            .keyboardShortcut(shortcut)
            .disabled(!shellReady)
    }

    /// The shell is published before `MacShellView` exists and before the first load finishes;
    /// gate window-scoped commands on both so they aren't live too early.
    private var shellReady: Bool {
        window != nil && bootstrap.didFinishLoading
    }

    private func goDestination(_ target: GoTarget) -> SidebarItem? {
        guard let window else { return nil }
        return CommandRouter.destination(for: target, current: window.selection, pets: store.pets)
    }

    private var periodAvailable: Bool {
        window.map { PeriodNavigator.isAvailable(on: $0.selection) } ?? false
    }
}
#endif
