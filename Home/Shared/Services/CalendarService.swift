// Home/Shared/Services/CalendarService.swift
import EventKit
import Foundation

enum CalendarService {

    private static let store = EKEventStore()

    static func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    @discardableResult
    static func addAppointment(_ appt: Appointment, petName: String) async -> Bool {
        guard await requestAccess() else { return false }
        let event = EKEvent(eventStore: store)
        event.title = "\(petName) — \(appt.reason)"
        event.startDate = appt.date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: appt.date) ?? appt.date
        event.notes = appt.notes.isEmpty ? nil : appt.notes
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func addPetEvent(_ petEvent: PetEvent, petName: String) async -> Bool {
        guard await requestAccess() else { return false }
        let event = EKEvent(eventStore: store)
        event.title = "\(petName) — \(petEvent.title)"
        event.startDate = petEvent.date
        event.endDate = petEvent.date
        event.isAllDay = true
        var notes = petEvent.category.label
        if let v = petEvent.value { notes += " (\(v))" }
        if !petEvent.notes.isEmpty { notes += "\n\(petEvent.notes)" }
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func addHouseholdTask(_ task: HouseholdTask) async -> Bool {
        guard await requestAccess() else { return false }
        let event = EKEvent(eventStore: store)
        event.title = task.title
        event.startDate = task.nextDueDate
        event.endDate = task.nextDueDate
        event.isAllDay = true
        event.notes = task.notes.isEmpty ? nil : task.notes
        event.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
}
