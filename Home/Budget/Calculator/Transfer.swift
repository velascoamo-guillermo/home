import Foundation

nonisolated struct Transfer: Equatable, Hashable, Sendable {
    let fromMemberId: UUID
    let toMemberId: UUID
    let amountCents: Int
}
