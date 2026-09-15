import Foundation

nonisolated enum StockLevel: String, Codable, CaseIterable, Comparable, Hashable {
    case out, low, medium, full

    var filledSegments: Int {
        switch self {
        case .out:    0
        case .low:    1
        case .medium: 2
        case .full:   3
        }
    }

    var needsRestock: Bool { self == .out || self == .low }

    var displayName: String {
        switch self {
        case .out:    "Out"
        case .low:    "Low"
        case .medium: "Medium"
        case .full:   "Full"
        }
    }

    func steppedDown() -> StockLevel {
        switch self {
        case .full:       .medium
        case .medium:     .low
        case .low, .out:  .out
        }
    }

    func steppedUp() -> StockLevel {
        switch self {
        case .out:           .low
        case .low:           .medium
        case .medium, .full: .full
        }
    }

    static func from(packages: Int, looseUnits: Int) -> StockLevel {
        if packages >= 2 { return .full }
        if packages == 1 { return .medium }
        return looseUnits >= 1 ? .low : .out
    }

    // Raw-value enums don't get synthesized Comparable.
    static func < (lhs: StockLevel, rhs: StockLevel) -> Bool {
        lhs.filledSegments < rhs.filledSegments
    }
}
