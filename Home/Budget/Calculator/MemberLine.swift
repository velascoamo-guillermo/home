import Foundation

nonisolated struct MemberLine: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let isFormer: Bool
    let sortOrder: Int
    let incomeCents: Int
    let incomeCarriedOver: Bool
    let ratioPercent: Int
    let shareCents: Int
    let paidCents: Int
    let balanceCents: Int
    let savingsCents: Int
}
