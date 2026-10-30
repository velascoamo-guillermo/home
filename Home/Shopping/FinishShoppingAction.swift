struct FinishShoppingAction: Equatable {
    enum Phase: Equatable {
        case idle, finishing, confirmed

        mutating func begin() -> Bool {
            guard self == .idle else { return false }
            self = .finishing
            return true
        }

        mutating func succeed() { self = .confirmed }
        mutating func fail() { self = .idle }

        mutating func dismissConfirmation() {
            if self == .confirmed { self = .idle }
        }
    }

    let count: Int
    var phase: Phase = .idle

    var isVisible: Bool { count > 0 || phase == .confirmed }
    var isEnabled: Bool { phase == .idle }
    var title: String { phase == .confirmed ? "Done ✓" : "Done · \(count)" }
    var accessibilityLabel: String { phase == .confirmed ? "Shopping finished" : "Finish shopping (\(count))" }
    var inputLabels: [String] { ["Done", "Finish shopping"] }
}
