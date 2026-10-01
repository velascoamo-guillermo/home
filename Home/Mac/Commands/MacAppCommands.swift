#if os(macOS)
import AppKit
import SwiftUI

struct MacAppCommands: Commands {
    let store: SupabaseStore
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
            Button("Open in New Window") {
                if let window { openWindow(value: MacWindowSeed.new(window.selection)) }
            }
            .disabled(window == nil)
        }

        // `.textEditing` is backed by SwiftUI's `TextEditingCommands` (bare `init()`, no
        // per-item customization) — it bundles the Find submenu together with Spelling and
        // Grammar, Substitutions, Transformations, Speech, and Start Dictation as one unit.
        // There is no public API to keep everything and only swap the Find item, and keeping
        // `TextEditingCommands()` as-is would duplicate ⌘F with our own Find item (Task 12).
        // Trade-off: we drop the native Find submenu's own items (Find Next/Previous, Use
        // Selection for Find, Jump to Selection — superseded by the `.searchable` field Task 12
        // wires up) but rebuild Spelling and Grammar, Substitutions, Transformations, Speech,
        // and Start Dictation via their standard AppKit responder-chain actions.
        CommandGroup(replacing: .textEditing) {
            Button("Find…") { window?.isSearchFocused = true }
                .keyboardShortcut("f")
                .disabled(window == nil)

            Divider()

            Menu("Spelling and Grammar") {
                Button("Show Spelling and Grammar") { sendTextAction("showGuessPanel:") }
                    .keyboardShortcut(";", modifiers: .command)
                Button("Check Document Now") { sendTextAction("checkSpelling:") }
                    .keyboardShortcut(";", modifiers: [.command, .shift])
                Divider()
                Button("Check Spelling While Typing") { sendTextAction("toggleContinuousSpellChecking:") }
                Button("Check Grammar With Spelling") { sendTextAction("toggleGrammarChecking:") }
                Button("Correct Spelling Automatically") { sendTextAction("toggleAutomaticSpellingCorrection:") }
            }

            Menu("Substitutions") {
                Button("Show Substitutions") { sendTextAction("orderFrontSubstitutionsPanel:") }
                Divider()
                Button("Smart Copy/Paste") { sendTextAction("toggleSmartInsertDelete:") }
                Button("Smart Quotes") { sendTextAction("toggleAutomaticQuoteSubstitution:") }
                Button("Smart Dashes") { sendTextAction("toggleAutomaticDashSubstitution:") }
                Button("Smart Links") { sendTextAction("toggleAutomaticLinkDetection:") }
                Button("Data Detectors") { sendTextAction("toggleAutomaticDataDetection:") }
                Button("Text Replacement") { sendTextAction("toggleAutomaticTextReplacement:") }
            }

            Menu("Transformations") {
                Button("Make Upper Case") { sendTextAction("uppercaseWord:") }
                Button("Make Lower Case") { sendTextAction("lowercaseWord:") }
                Button("Capitalize") { sendTextAction("capitalizeWord:") }
            }

            Menu("Speech") {
                Button("Start Speaking") { sendTextAction("startSpeaking:") }
                Button("Stop Speaking") { sendTextAction("stopSpeaking:") }
            }

            Button("Start Dictation…") { sendTextAction("startDictation:") }
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
    }

    /// Forwards a standard Cocoa text-editing action (e.g. `showGuessPanel:`) up the responder
    /// chain, the same way the system's own Spelling/Substitutions/Transformations/Speech menu
    /// items dispatch. These selectors are not imported into Swift, so they're looked up by name.
    private func sendTextAction(_ selectorName: String) {
        NSApp.sendAction(Selector(selectorName), to: nil, from: nil)
    }

    private func newButton(_ action: MacPendingAction, _ shortcut: KeyboardShortcut?) -> some View {
        Button(action.title) { window?.perform(action) }
            .keyboardShortcut(shortcut)
            .disabled(window == nil)
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
