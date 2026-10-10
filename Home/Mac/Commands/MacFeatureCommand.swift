#if os(macOS)
import Foundation

/// Selection-scoped actions that also live in context menus or feature toolbars; the File menu
/// carries them too so every command is in the menu bar (HIG).
enum MacFeatureCommand: Hashable, CaseIterable, Sendable {
    case markDone, snoozeOneDay, markBought, finishShopping, suggestWeek

    var title: String {
        switch self {
        case .markDone:       "Mark as Done"
        case .snoozeOneDay:   "Snooze One Day"
        case .markBought:     "Mark as Bought"
        case .finishShopping: "Finish Shopping"
        case .suggestWeek:    "Suggest Week"
        }
    }
}
#endif
