nonisolated enum ChipSelection {
    static func next<Item: Hashable>(current: Item, tapped: Item) -> Item {
        tapped
    }

    static func next<Item: Hashable>(current: Item?, tapped: Item) -> Item? {
        current == tapped ? nil : tapped
    }
}
