import Foundation

enum AgendaBuilder {
    private struct Placed {
        let section: AgendaSection
        let item: AgendaItem
        let time: Date?
        let rank: Int
    }

    static func build(day: Date, today: Date, calendar: Calendar, input: AgendaInput) -> AgendaDay {
        let day = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: today)

        let placed = tasks(input.tasks, day: day, today: today, calendar: calendar)
            + appointments(input, day: day, today: today, calendar: calendar)
            + petEvents(input, day: day, calendar: calendar)
            + meals(input, day: day, calendar: calendar)
            + calendarEvents(input.calendarEvents, day: day, calendar: calendar)

        let groups = AgendaSection.allCases.compactMap { section -> AgendaGroup? in
            let items = placed.filter { $0.section == section }.sorted(by: precedes).map(\.item)
            return items.isEmpty ? nil : AgendaGroup(section: section, items: items)
        }
        return AgendaDay(date: day, groups: groups)
    }

    static func dotCount(day: Date, today: Date, calendar: Calendar, input: AgendaInput) -> Int {
        build(day: day, today: today, calendar: calendar, input: input).groups
            .filter { $0.section != .overdue }
            .reduce(0) { $0 + $1.items.count }
    }

    // MenuEntry.dayOfWeek is ISO (1 = Monday); Calendar's weekday is 1 = Sunday.
    static func isoWeekday(of day: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: day)
        return weekday == 1 ? 7 : weekday - 1
    }

    // Untimed first, then time, then type rank, then title.
    private static func precedes(_ lhs: Placed, _ rhs: Placed) -> Bool {
        switch (lhs.time, rhs.time) {
        case (nil, .some): return true
        case (.some, nil): return false
        case let (l?, r?) where l != r: return l < r
        default: break
        }
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.item.title.localizedStandardCompare(rhs.item.title) == .orderedAscending
    }

    private static func tasks(_ tasks: [HouseholdTask], day: Date, today: Date, calendar: Calendar) -> [Placed] {
        tasks.compactMap { task in
            guard let occurrence = TaskOccurrence.of(task, on: day, today: today, calendar: calendar) else { return nil }
            if case .overdue = occurrence {
                return Placed(section: .overdue, item: .task(task, occurrence), time: task.nextDueDate, rank: 1)
            }
            return Placed(section: .anytime, item: .task(task, occurrence), time: nil, rank: 1)
        }
    }

    private static func appointments(_ input: AgendaInput, day: Date, today: Date, calendar: Calendar) -> [Placed] {
        input.appointments.compactMap { appt in
            guard calendar.isDate(appt.date, inSameDayAs: day) else { return nil }
            switch appt.status {
            case .cancelled: return nil
            case .done where day >= today: return nil
            default: break
            }
            guard let pet = input.pets.first(where: { $0.id == appt.petId }) else { return nil }
            let section = AgendaSection.timeBucket(hour: calendar.component(.hour, from: appt.date))
            return Placed(section: section, item: .appointment(appt, pet), time: appt.date, rank: 1)
        }
    }

    // Pet event UI only captures a date, so its time component is not meaningful.
    private static func petEvents(_ input: AgendaInput, day: Date, calendar: Calendar) -> [Placed] {
        input.petEvents.compactMap { event in
            guard calendar.isDate(event.date, inSameDayAs: day),
                  let pet = input.pets.first(where: { $0.id == event.petId }) else { return nil }
            return Placed(section: .anytime, item: .petEvent(event, pet), time: nil, rank: 0)
        }
    }

    private static func meals(_ input: AgendaInput, day: Date, calendar: Calendar) -> [Placed] {
        let weekday = isoWeekday(of: day, calendar: calendar)
        var latest: [MealSlot: MenuEntry] = [:]
        for entry in input.menuEntries where entry.dayOfWeek == weekday {
            if let existing = latest[entry.slot], existing.updatedAt >= entry.updatedAt { continue }
            latest[entry.slot] = entry
        }
        return latest.values.compactMap { entry in
            guard let meal = input.meals.first(where: { $0.id == entry.mealId }),
                  !meal.title.isEmpty else { return nil }
            let section: AgendaSection = entry.slot == .lunch ? .afternoon : .evening
            return Placed(section: section, item: .meal(meal, entry.slot), time: nil, rank: 2)
        }
    }

    private static func calendarEvents(_ events: [CalendarEventSnapshot], day: Date, calendar: Calendar) -> [Placed] {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { return [] }
        return events.compactMap { event in
            let startsToday = event.start >= day && event.start < dayEnd
            let overlaps = event.start < dayEnd && event.end > day
            guard startsToday || overlaps else { return nil }

            if event.isAllDay {
                return Placed(section: .allDay, item: .calendarEvent(event, continuesFromPreviousDay: false), time: nil, rank: 0)
            }
            if startsToday {
                let section = AgendaSection.timeBucket(hour: calendar.component(.hour, from: event.start))
                return Placed(section: section, item: .calendarEvent(event, continuesFromPreviousDay: false), time: event.start, rank: 0)
            }
            if event.end >= dayEnd {
                return Placed(section: .allDay, item: .calendarEvent(event, continuesFromPreviousDay: true), time: nil, rank: 0)
            }
            return Placed(section: .morning, item: .calendarEvent(event, continuesFromPreviousDay: true), time: day, rank: 0)
        }
    }
}
