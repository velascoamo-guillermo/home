// HomeTests/SupabaseStoreFilterTests.swift
import Testing
import Foundation
@testable import Home

@Suite("SupabaseStore – additional filters") @MainActor struct SupabaseStoreFilterTests {

    // MARK: - clinicalEntries(for:)

    @Test("clinicalEntries(for:) returns only matching petId")
    func clinicalEntriesFilter() {
        let store = SupabaseStore()
        let petA = UUID()
        let petB = UUID()
        store.clinicalEntries = [
            ClinicalEntry(petId: petA, date: .now, title: "Annual", description: ""),
            ClinicalEntry(petId: petB, date: .now, title: "Dental", description: ""),
        ]
        #expect(store.clinicalEntries(for: petA).count == 1)
        #expect(store.clinicalEntries(for: petA)[0].title == "Annual")
        #expect(store.clinicalEntries(for: UUID()).isEmpty)
    }

    @Test("clinicalEntries(for:) returns results sorted newest first")
    func clinicalEntriesSortedDescending() {
        let store = SupabaseStore()
        let petId = UUID()
        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)
        store.clinicalEntries = [
            ClinicalEntry(petId: petId, date: older, title: "Older", description: ""),
            ClinicalEntry(petId: petId, date: newer, title: "Newer", description: ""),
        ]
        let results = store.clinicalEntries(for: petId)
        #expect(results[0].title == "Newer")
        #expect(results[1].title == "Older")
    }

    // MARK: - events(for:)

    @Test("events(for:) returns only matching petId")
    func eventsFilter() {
        let store = SupabaseStore()
        let petA = UUID()
        let petB = UUID()
        store.events = [
            PetEvent(petId: petA, date: .now, title: "Vacc", category: .vaccine, notes: ""),
            PetEvent(petId: petB, date: .now, title: "Groom", category: .grooming, notes: ""),
        ]
        #expect(store.events(for: petA).count == 1)
        #expect(store.events(for: UUID()).isEmpty)
    }

    @Test("events(for:) returns results sorted newest first")
    func eventsSortedDescending() {
        let store = SupabaseStore()
        let petId = UUID()
        let older = Date(timeIntervalSince1970: 500_000)
        let newer = Date(timeIntervalSince1970: 900_000)
        store.events = [
            PetEvent(petId: petId, date: older, title: "First", category: .other, notes: ""),
            PetEvent(petId: petId, date: newer, title: "Second", category: .vaccine, notes: ""),
        ]
        let results = store.events(for: petId)
        #expect(results[0].title == "Second")
        #expect(results[1].title == "First")
    }

    // MARK: - files(for:linkedToId:)

    @Test("files(for:linkedToId:) filters by linkedToId")
    func filesFilterByLinkedId() {
        let store = SupabaseStore()
        let petId = UUID()
        let eventId = UUID()
        let otherEventId = UUID()
        store.files = [
            PetFile(petId: petId, storagePath: "a/1.jpg", sourceType: .photo,
                    linkedToType: "event", linkedToId: eventId, createdAt: .now),
            PetFile(petId: petId, storagePath: "a/2.jpg", sourceType: .photo,
                    linkedToType: "event", linkedToId: otherEventId, createdAt: .now),
        ]
        #expect(store.files(for: petId, linkedToType: "event", linkedToId: eventId).count == 1)
        #expect(store.files(for: petId, linkedToType: "event", linkedToId: UUID()).isEmpty)
    }

    // MARK: - homeTimeline edge cases

    @Test("homeTimeline is empty when store has no data")
    func homeTimelineEmpty() {
        let store = SupabaseStore()
        #expect(store.homeTimeline.isEmpty)
    }

    @Test("homeTimeline includes tasks when no appointments exist")
    func homeTimelineTasksOnly() {
        let store = SupabaseStore()
        store.householdTasks = [
            HouseholdTask(title: "Water plants", icon: "drop", intervalDays: 3, nextDueDate: .now),
        ]
        #expect(store.homeTimeline.count == 1)
        if case .task(let t) = store.homeTimeline[0] {
            #expect(t.title == "Water plants")
        } else {
            Issue.record("Expected .task item")
        }
    }

    @Test("homeTimeline includes all three status buckets correctly — only upcoming shown")
    func homeTimelineAllStatuses() {
        let store = SupabaseStore()
        let pet = Pet(name: "Kiko", type: "dog", breed: "poodle")
        store.pets = [pet]
        store.appointments = [
            Appointment(petId: pet.id, date: .now, reason: "A", notes: "", status: .upcoming),
            Appointment(petId: pet.id, date: .now, reason: "B", notes: "", status: .done),
            Appointment(petId: pet.id, date: .now, reason: "C", notes: "", status: .cancelled),
        ]
        #expect(store.homeTimeline.count == 1)
    }
}
