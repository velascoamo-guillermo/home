// HomeTests/HomeItemTests.swift
import Testing
import Foundation
@testable import Home

@Suite("HomeItem") @MainActor struct HomeItemTests {

    // MARK: - id

    @Test("id returns appointment id for .appointment case")
    func idForAppointment() {
        let appt = Appointment(petId: UUID(), date: .now, reason: "check", notes: "", status: .upcoming)
        let pet  = Pet(name: "Luna", type: "cat", breed: "mixed")
        let item = HomeItem.appointment(appt, pet)
        #expect(item.id == appt.id)
    }

    @Test("id returns task id for .task case")
    func idForTask() {
        let task = HouseholdTask(title: "Feed", icon: "fork.knife", intervalDays: 1, nextDueDate: .now)
        let item = HomeItem.task(task)
        #expect(item.id == task.id)
    }

    // MARK: - dueDate

    @Test("dueDate returns appointment date for .appointment case")
    func dueDateForAppointment() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let appt = Appointment(petId: UUID(), date: date, reason: "vacc", notes: "", status: .upcoming)
        let pet  = Pet(name: "Rex", type: "dog", breed: "lab")
        let item = HomeItem.appointment(appt, pet)
        #expect(item.dueDate == date)
    }

    @Test("dueDate returns nextDueDate for .task case")
    func dueDateForTask() {
        let date = Date(timeIntervalSince1970: 2_000_000)
        let task = HouseholdTask(title: "Filter", icon: "drop", intervalDays: 90, nextDueDate: date)
        let item = HomeItem.task(task)
        #expect(item.dueDate == date)
    }
}
