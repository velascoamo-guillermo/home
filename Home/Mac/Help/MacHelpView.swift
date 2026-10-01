#if os(macOS)
import SwiftUI

struct MacHelpView: View {
    static let windowID = "help"

    private let shortcuts: [(String, String)] = [
        ("New Task", "⌘N"), ("New Expense", "⇧⌘E"), ("New Shopping Item", "⇧⌘L"),
        ("Find", "⌘F"), ("Refresh", "⌘R"), ("Show or Hide Inspector", "⌥⌘I"),
        ("Today … Pets", "⌘1 … ⌘7"), ("Previous or Next Month in Budget", "⌘[ ⌘]"),
        ("Settings", "⌘,"),
    ]

    var body: some View {
        Form {
            Section {
                Text("Casita keeps the household in sync between your iPhone and this Mac. Choose an area in the sidebar; add items with the + in the toolbar or the File menu; select an item and press Return to see its details.")
            }
            Section("Keyboard Shortcuts") {
                ForEach(shortcuts, id: \.0) { name, keys in
                    LabeledContent(name, value: keys)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
    }
}
#endif
