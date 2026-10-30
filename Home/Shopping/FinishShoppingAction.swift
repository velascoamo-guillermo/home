struct FinishShoppingAction: Equatable {
    let count: Int

    var isVisible: Bool { count > 0 }
    var title: String { "Done · \(count)" }
    var accessibilityLabel: String { "Finish shopping (\(count))" }
}
