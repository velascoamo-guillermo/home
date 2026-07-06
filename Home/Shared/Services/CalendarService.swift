// Home/Shared/Services/CalendarService.swift
import EventKit
import Foundation

enum CalendarService {

    private static let store = EKEventStore()

    enum ReminderOffset: CaseIterable {
        case atTime, oneHourBefore, oneDayBefore

        var label: String {
            switch self {
            case .atTime:        return "At time"
            case .oneHourBefore: return "1 hour before"
            case .oneDayBefore:  return "1 day before"
            }
        }

        var relativeOffset: TimeInterval {
            switch self {
            case .atTime:        return 0
            case .oneHourBefore: return -3600
            case .oneDayBefore:  return -86400
            }
        }
    }

    static func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    @discardableResult
    static func addAppointment(_ appt: Appointment, petName: String, reminder: ReminderOffset? = nil) async -> Bool {
        guard await requestAccess() else { return false }
        let event = EKEvent(eventStore: store)
        event.title = "\(petName) — \(appt.reason)"
        event.startDate = appt.date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: appt.date) ?? appt.date
        event.notes = appt.notes.isEmpty ? nil : appt.notes
        event.calendar = store.defaultCalendarForNewEvents
        if let reminder { event.addAlarm(EKAlarm(relativeOffset: reminder.relativeOffset)) }
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func addPetEvent(_ petEvent: PetEvent, petName: String, reminder: ReminderOffset? = nil) async -> Bool {
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
        if let reminder { event.addAlarm(EKAlarm(relativeOffset: reminder.relativeOffset)) }
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func addHouseholdTask(_ task: HouseholdTask, reminder: ReminderOffset? = nil) async -> Bool {
        guard await requestAccess() else { return false }
        let event = EKEvent(eventStore: store)
        event.title = task.title
        event.startDate = task.nextDueDate
        event.endDate = task.nextDueDate
        event.isAllDay = true
        event.notes = task.notes.isEmpty ? nil : task.notes
        event.calendar = store.defaultCalendarForNewEvents
        if let reminder { event.addAlarm(EKAlarm(relativeOffset: reminder.relativeOffset)) }
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
}
