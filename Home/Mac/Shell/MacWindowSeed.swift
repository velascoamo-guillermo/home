#if os(macOS)
import Foundation

/// A window's scene value. `openWindow(value:)` focuses an existing window presenting an equal
/// value, so each window keeps its `id` for life and only `item` follows the selection; opening
/// a new window always uses a fresh `id`.
nonisolated struct MacWindowSeed: Codable, Hashable, Sendable {
    var id: UUID
    var item: SidebarItem

    static func new(_ item: SidebarItem) -> MacWindowSeed {
        MacWindowSeed(id: UUID(), item: item)
    }
}
#endif
