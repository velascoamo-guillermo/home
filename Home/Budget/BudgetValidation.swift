import Foundation

nonisolated enum BudgetValidation {
    static let maxAmountCents = 100_000_000

    static func amount(_ cents: Int) throws {
        guard cents > 0 else { throw BudgetValidationError.invalidAmount }
        guard cents <= maxAmountCents else { throw BudgetValidationError.amountTooLarge }
    }

    static func name(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BudgetValidationError.emptyName
        }
    }

    static func nonNegativeAmount(_ cents: Int) throws {
        guard cents >= 0 else { throw BudgetValidationError.invalidAmount }
        guard cents <= maxAmountCents else { throw BudgetValidationError.amountTooLarge }
    }

    static func dayOfMonth(_ day: Int) throws {
        guard (1...28).contains(day) else { throw BudgetValidationError.dayOutOfRange }
    }
}
