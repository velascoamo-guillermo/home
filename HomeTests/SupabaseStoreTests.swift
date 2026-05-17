// HomeTests/SupabaseStoreTests.swift
import Testing
import Foundation
@testable import Home

@Suite("SupabaseStore filters") struct SupabaseStoreTests {

    @Test("appointments(for:) returns only matching petId")
    func appointmentsFilter() {
        let store = SupabaseStore()
        let petA = UUID()
        let petB = UUID()
        store.appointments = [
            Appointment(petId: petA, date: .now, reason: "check", notes: "", status: .upcoming),
            Appointment(petId: petB, date: .now, reason: "vacc", notes: "", status: .upcoming)
        ]
        #expect(store.appointments(for: petA).count == 1)
        #expect(store.appointments(for: petA)[0].reason == "check")
    }

    @Test("files(for:linkedToType:) filters by petId and type")
    func filesFilter() {
        let store = SupabaseStore()
        let petId = UUID()
        let eventId = UUID()
        store.files = [
            PetFile(petId: petId, storagePath: "a/b.jpg", sourceType: .photo,
                    linkedToType: "standalone", linkedToId: nil, createdAt: .now),
            PetFile(petId: petId, storagePath: "a/c.pdf", sourceType: .document,
                    linkedToType: "event", linkedToId: eventId, createdAt: .now)
        ]
        #expect(store.files(for: petId, linkedToType: "standalone").count == 1)
        #expect(store.files(for: petId).count == 2)
        #expect(store.files(for: UUID()).count == 0)
    }
}
