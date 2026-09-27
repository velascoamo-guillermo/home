import Foundation

nonisolated enum BudgetValidationError: LocalizedError, Equatable {
    case invalidAmount
    case amountTooLarge
    case emptyName
    case missingCategory
    case missingPayer
    case categoryInUse
    case lastMember

    var errorDescription: String? {
        switch self {
        case .invalidAmount:   "Enter an amount greater than zero."
        case .amountTooLarge:  "Amounts can't exceed €1,000,000.00."
        case .emptyName:       "Name can't be empty."
        case .missingCategory: "Pick a category."
        case .missingPayer:    "Pick who paid."
        case .categoryInUse:   "This category has expenses or bills. Archive it instead."
        case .lastMember:      "Keep at least one member."
        }
    }
}
