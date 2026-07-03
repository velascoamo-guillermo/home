// HomeTests/SupabaseStoreTests.swift
import Testing
import Foundation
@testable import Casita

@Suite("SupabaseStore filters") @MainActor struct SupabaseStoreTests {

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

    @Test("homeTimeline sorts appointments and tasks by dueDate")
    func homeTimelineSorted() {
        let store = SupabaseStore()
        let pet = Pet(name: "Rex", type: "dog", breed: "lab")
        store.pets = [pet]

        let sooner = Date.now.addingTimeInterval(3600)
        let later  = Date.now.addingTimeInterval(7200)

        store.appointments   = [Appointment(petId: pet.id, date: later,  reason: "checkup", notes: "", status: .upcoming)]
        store.householdTasks = [HouseholdTask(title: "Filter", icon: "drop", intervalDays: 90, nextDueDate: sooner)]

        let timeline = store.homeTimeline
        #expect(timeline.count == 2)
        #expect(timeline[0].dueDate <= timeline[1].dueDate)
    }

    @Test("homeTimeline excludes done and cancelled appointments")
    func homeTimelineExcludesNonUpcoming() {
        let store = SupabaseStore()
        let pet = Pet(name: "Rex", type: "dog", breed: "lab")
        store.pets = [pet]
        store.appointments = [
            Appointment(petId: pet.id, date: .now, reason: "done",      notes: "", status: .done),
            Appointment(petId: pet.id, date: .now, reason: "cancelled",  notes: "", status: .cancelled),
            Appointment(petId: pet.id, date: .now, reason: "upcoming",   notes: "", status: .upcoming)
        ]
        #expect(store.homeTimeline.count == 1)
    }

    @Test("homeTimeline excludes appointment with missing pet")
    func homeTimelineDropsOrphanedAppointment() {
        let store = SupabaseStore()
        store.pets = []
        store.appointments = [
            Appointment(petId: UUID(), date: .now, reason: "orphan", notes: "", status: .upcoming)
        ]
        #expect(store.homeTimeline.count == 0)
    }
}
