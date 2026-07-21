import Foundation

@MainActor
enum DashboardData {
    static let taskLimit = 3
    static let shoppingLimit = 3
    static let mealLimit = 3
    static let appointmentLimit = 3

    static func upcomingTasks(
        tasks: [HouseholdTask], events: [PetEvent], pets: [Pet], today: Date, limit: Int
    ) -> (items: [HomeItem], total: Int) {
        let startOfToday = Calendar.current.startOfDay(for: today)
        let taskItems = tasks.map { HomeItem.task($0) }
        let eventItems = events
            .filter { $0.date >= startOfToday }
            .compactMap { event -> HomeItem? in
                guard let pet = pets.first(where: { $0.id == event.petId }) else { return nil }
                return .event(event, pet)
            }
        let all = (taskItems + eventItems).sorted { $0.dueDate < $1.dueDate }
        return (Array(all.prefix(limit)), all.count)
    }

    static func shoppingList(stock: [StockProduct], limit: Int) -> (items: [StockProduct], total: Int) {
        let out = stock.filter { $0.totalUnits == 0 }
        return (Array(out.prefix(limit)), out.count)
    }

    struct WeekMeal: Identifiable {
        let entry: MenuEntry
        let meal: Meal
        var id: UUID { entry.id }
    }

    static func weekMeals(
        entries: [MenuEntry], meals: [Meal], todayWeekday: Int, limit: Int
    ) -> (items: [WeekMeal], total: Int) {
        let slotOrder: (MealSlot) -> Int = { MealSlot.allCases.firstIndex(of: $0) ?? 0 }
        let planned = entries.compactMap { entry -> WeekMeal? in
            guard let meal = meals.first(where: { $0.id == entry.mealId }),
                  !meal.title.isEmpty else { return nil }
            return WeekMeal(entry: entry, meal: meal)
        }
        let rotated = planned.sorted { lhs, rhs in
            let l = (lhs.entry.dayOfWeek - todayWeekday + 7) % 7
            let r = (rhs.entry.dayOfWeek - todayWeekday + 7) % 7
            if l != r { return l < r }
            return slotOrder(lhs.entry.slot) < slotOrder(rhs.entry.slot)
        }
        return (Array(rotated.prefix(limit)), rotated.count)
    }

    static func upcomingAppointments(
        appointments: [Appointment], pets: [Pet], limit: Int
    ) -> (items: [HomeItem], total: Int) {
        let all = appointments
            .filter { $0.status == .upcoming }
            .compactMap { appt -> HomeItem? in
                guard let pet = pets.first(where: { $0.id == appt.petId }) else { return nil }
                return .appointment(appt, pet)
            }
            .sorted { $0.dueDate < $1.dueDate }
        return (Array(all.prefix(limit)), all.count)
    }
}
