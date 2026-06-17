import Foundation

/// A model that can live in LocalStore and sync to a Supabase table.
/// Implemented by structs whose primary key is a client-generated UUID.
protocol SyncableEntity: Codable, Identifiable, Sendable where ID == UUID {
    nonisolated static var tableName: String { get }
    nonisolated var id: UUID { get }
    nonisolated var updatedAt: Date { get set }
    nonisolated var deletedAt: Date? { get set }
}
