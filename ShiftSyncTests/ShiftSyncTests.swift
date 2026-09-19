//
//  ShiftSyncTests.swift
//  ShiftSyncTests
//

import Testing
import Foundation
@testable import ShiftSync

// ShiftStore is always constructed here with an isolated UserDefaults suite, NEVER
// .standard — this test bundle runs hosted inside the real app's process/container on
// whatever simulator or device runs it, so ShiftStore(defaults: .standard) would read
// and (via clearAll()) WIPE the real app's actual saved shift data. Learned this the
// hard way: an earlier version of this file used the default (.standard) and every
// `clearAll()` call — present in nearly every test's cleanup — permanently erased
// whatever real shift entries existed on the simulator these tests ran on.
private let testDefaults = UserDefaults(suiteName: "com.shiftsync.tests")!

// AppSettings has no injectable-storage equivalent yet, so tests that touch
// AppSettings.shared do share the real settings singleton — but unlike ShiftStore,
// nothing here ever deletes data; every test snapshots the exact properties it
// changes and restores them via `defer`, which runs even if an #expect fails.
// Tests run serialized (not in parallel) so those snapshot/restore pairs can't race.
@Suite(.serialized)
struct ShiftSyncTests {

    // MARK: - Pay calculation

    @Test func regularShiftPayIsHoursTimesRate() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        defer { settings.hourlyRate = originalRate; settings.paymentType = originalType }

        settings.paymentType = .hourly
        settings.hourlyRate = 20

        let entry = ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 480, unpaidBreakMinutes: 0)
        #expect(entry.estimatedPay == 160) // 8h * $20
    }

    @Test func unpaidBreakIsDeductedBeforePay() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        defer { settings.hourlyRate = originalRate; settings.paymentType = originalType }

        settings.paymentType = .hourly
        settings.hourlyRate = 20

        let entry = ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 480, unpaidBreakMinutes: 30)
        #expect(entry.estimatedPay == 150) // 7.5h * $20
    }

    @Test func overtimePayUsesConfiguredMultiplier() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        let originalMultiplier = settings.overtimeMultiplier
        defer {
            settings.hourlyRate = originalRate
            settings.paymentType = originalType
            settings.overtimeMultiplier = originalMultiplier
        }

        settings.paymentType = .hourly
        settings.hourlyRate = 20
        settings.overtimeMultiplier = 1.5

        let entry = ShiftEntry(shiftType: .overtime, startedAt: Date(), durationMinutes: 120, unpaidBreakMinutes: 0)
        #expect(entry.estimatedPay == 60) // 2h * $20 * 1.5
    }

    @Test func holidayPayIsAlwaysDoubleRegardlessOfOvertimeMultiplier() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        let originalMultiplier = settings.overtimeMultiplier
        defer {
            settings.hourlyRate = originalRate
            settings.paymentType = originalType
            settings.overtimeMultiplier = originalMultiplier
        }

        settings.paymentType = .hourly
        settings.hourlyRate = 20
        settings.overtimeMultiplier = 2.0 // deliberately matches holiday's 2x to prove it's not reading this

        let entry = ShiftEntry(shiftType: .holiday, startedAt: Date(), durationMinutes: 480, unpaidBreakMinutes: 0)
        #expect(entry.estimatedPay == 320) // 8h * $20 * 2.0 (holiday's own fixed multiplier)
    }

    @Test func dayTypePayUsesDailyRateTimesDayCount() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        let originalHours = settings.workDayHours
        defer {
            settings.hourlyRate = originalRate
            settings.paymentType = originalType
            settings.workDayHours = originalHours
        }

        settings.paymentType = .hourly
        settings.hourlyRate = 20
        settings.workDayHours = 8

        // 3 vacation days bundled into a single entry (as EditShiftView's day stepper does)
        let entry = ShiftEntry(shiftType: .vacation, startedAt: Date(), durationMinutes: 3 * 8 * 60, unpaidBreakMinutes: 0)
        #expect(entry.dayCount == 3)
        #expect(entry.estimatedPay == 480) // 3 days * 8h * $20
    }

    @Test func payOverrideLocksPayRegardlessOfCurrentSettings() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        defer { settings.hourlyRate = originalRate; settings.paymentType = originalType }

        settings.paymentType = .hourly
        settings.hourlyRate = 999 // should be ignored entirely

        let entry = ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 480,
                               unpaidBreakMinutes: 0, payOverride: 42)
        #expect(entry.estimatedPay == 42)
    }

    // MARK: - ShiftStore: overtime split on clock-out

    @Test func clockOutSplitsShiftWhenOvertimeEnabledAndThresholdExceeded() {
        let settings = AppSettings.shared
        let originalEnabled = settings.overtimeEnabled
        let originalThreshold = settings.dailyOvertimeHours
        defer {
            settings.overtimeEnabled = originalEnabled
            settings.dailyOvertimeHours = originalThreshold
        }
        settings.overtimeEnabled = true
        settings.dailyOvertimeHours = 8

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        store.activeShiftStart = Date().addingTimeInterval(-10 * 3600) // 10h ago
        store.clockOut()

        #expect(store.entries.count == 2)
        let regular = store.entries.first { $0.shiftType == .regular }
        let overtime = store.entries.first { $0.shiftType == .overtime }
        #expect(regular?.durationMinutes == 480)   // capped at 8h threshold
        #expect(overtime?.durationMinutes == 120)  // remaining 2h
    }

    @Test func clockOutDoesNotSplitWhenUnderThreshold() {
        let settings = AppSettings.shared
        let originalEnabled = settings.overtimeEnabled
        let originalThreshold = settings.dailyOvertimeHours
        defer {
            settings.overtimeEnabled = originalEnabled
            settings.dailyOvertimeHours = originalThreshold
        }
        settings.overtimeEnabled = true
        settings.dailyOvertimeHours = 8

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        store.activeShiftStart = Date().addingTimeInterval(-6 * 3600) // 6h ago, under threshold
        store.clockOut()

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.shiftType == .regular)
    }

    @Test func clockOutNeverSplitsWhenOvertimeDisabled() {
        let settings = AppSettings.shared
        let originalEnabled = settings.overtimeEnabled
        defer { settings.overtimeEnabled = originalEnabled }
        settings.overtimeEnabled = false

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        store.activeShiftStart = Date().addingTimeInterval(-12 * 3600) // way over any threshold
        store.clockOut()

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.shiftType == .regular)
        #expect(store.entries.first?.durationMinutes == 720)
    }

    // MARK: - ShiftStore: retroactive Overtime Rules changes

    @Test func reapplyOvertimeRulesSplitsExistingEntriesExceedingNewThreshold() {
        let settings = AppSettings.shared
        let originalEnabled = settings.overtimeEnabled
        let originalThreshold = settings.dailyOvertimeHours
        defer {
            settings.overtimeEnabled = originalEnabled
            settings.dailyOvertimeHours = originalThreshold
        }

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        // Logged before overtime rules existed: a plain 10h Regular entry.
        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 600, unpaidBreakMinutes: 0))

        settings.overtimeEnabled = true
        settings.dailyOvertimeHours = 8
        store.reapplyOvertimeRulesToExistingEntries()

        #expect(store.entries.count == 2)
        #expect(store.entries.contains { $0.shiftType == .regular && $0.durationMinutes == 480 })
        #expect(store.entries.contains { $0.shiftType == .overtime && $0.durationMinutes == 120 })
    }

    @Test func reapplyOvertimeRulesLeavesShortEntriesUntouched() {
        let settings = AppSettings.shared
        let originalEnabled = settings.overtimeEnabled
        let originalThreshold = settings.dailyOvertimeHours
        defer {
            settings.overtimeEnabled = originalEnabled
            settings.dailyOvertimeHours = originalThreshold
        }

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 360, unpaidBreakMinutes: 0)) // 6h

        settings.overtimeEnabled = true
        settings.dailyOvertimeHours = 8
        store.reapplyOvertimeRulesToExistingEntries()

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.shiftType == .regular)
        #expect(store.entries.first?.durationMinutes == 360)
    }

    @Test func reapplyOvertimeRulesNeverSplitsDayTypeEntries() {
        let settings = AppSettings.shared
        let originalEnabled = settings.overtimeEnabled
        let originalThreshold = settings.dailyOvertimeHours
        defer {
            settings.overtimeEnabled = originalEnabled
            settings.dailyOvertimeHours = originalThreshold
        }

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        // A long vacation entry (e.g. several bundled days) should never be split — only
        // live-clocked "Regular" shifts represent a single continuous workday.
        store.addEntry(ShiftEntry(shiftType: .vacation, startedAt: Date(), durationMinutes: 1000, unpaidBreakMinutes: 0))

        settings.overtimeEnabled = true
        settings.dailyOvertimeHours = 8
        store.reapplyOvertimeRulesToExistingEntries()

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.shiftType == .vacation)
    }

    @Test func reapplyOvertimeRulesClearsExistingPayOverride() {
        let settings = AppSettings.shared
        let originalEnabled = settings.overtimeEnabled
        defer { settings.overtimeEnabled = originalEnabled }

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 240,
                                  unpaidBreakMinutes: 0, payOverride: 999))

        settings.overtimeEnabled = false // no split path taken, but override should still clear
        store.reapplyOvertimeRulesToExistingEntries()

        #expect(store.entries.first?.payOverride == nil)
    }

    // MARK: - ShiftStore: freezing pay for "Only Future Shifts"

    @Test func freezePayLocksExistingEntriesAgainstLaterSettingsChanges() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        defer { settings.hourlyRate = originalRate; settings.paymentType = originalType }

        settings.paymentType = .hourly
        settings.hourlyRate = 10

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 480, unpaidBreakMinutes: 0))
        #expect(store.entries.first?.estimatedPay == 80) // 8h * $10

        store.freezePayForExistingEntries()
        settings.hourlyRate = 500 // a later rate change should no longer affect this entry

        #expect(store.entries.first?.payOverride == 80)
        #expect(store.entries.first?.estimatedPay == 80)
    }

    @Test func freezePayDoesNotAffectEntriesAddedAfterward() {
        let settings = AppSettings.shared
        let originalRate = settings.hourlyRate
        let originalType = settings.paymentType
        defer { settings.hourlyRate = originalRate; settings.paymentType = originalType }

        settings.paymentType = .hourly
        settings.hourlyRate = 10

        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 480, unpaidBreakMinutes: 0))
        store.freezePayForExistingEntries()

        settings.hourlyRate = 20
        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 480, unpaidBreakMinutes: 0))

        let frozen = store.entries[0]
        let fresh = store.entries[1]
        #expect(frozen.estimatedPay == 80)  // still the old, frozen rate
        #expect(fresh.estimatedPay == 160)  // computes live at the new rate
    }

    // MARK: - ShiftStore: basic CRUD

    @Test func deleteEntryRemovesOnlyTheMatchingEntry() {
        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        let keep = ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 60, unpaidBreakMinutes: 0)
        let remove = ShiftEntry(shiftType: .regular, startedAt: Date(), durationMinutes: 120, unpaidBreakMinutes: 0)
        store.addEntry(keep)
        store.addEntry(remove)

        store.deleteEntry(id: remove.id)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.id == keep.id)
    }

    @Test func hasShiftsOnDetectsSameCalendarDayRegardlessOfTime() {
        let store = ShiftStore(defaults: testDefaults)
        store.clearAll()
        defer { store.clearAll() }

        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: morning, durationMinutes: 60, unpaidBreakMinutes: 0))

        #expect(store.hasShifts(on: Date()))
    }

    // MARK: - AppSettings: day-label formatting (pure function, no shared state)

    @Test func daysLabelForEmptySetSaysNoDaysSelected() {
        #expect(AppSettings.daysLabel([]) == "No days selected")
    }

    @Test func daysLabelForAllSevenDaysSaysEveryDay() {
        #expect(AppSettings.daysLabel([1, 2, 3, 4, 5, 6, 7]) == "Every day")
    }

    @Test func daysLabelForMondayToFridayUsesWeekdaysShorthand() {
        #expect(AppSettings.daysLabel([2, 3, 4, 5, 6]) == "Weekdays (Mon–Fri)")
    }

    @Test func daysLabelForCustomSetListsAbbreviatedDaysInOrder() {
        // Sunday (1), Wednesday (4), Saturday (7) — deliberately unsorted input
        #expect(AppSettings.daysLabel([7, 1, 4]) == "Sun, Wed, Sat")
    }

    // MARK: - AppSettings: rate calculations

    @Test func effectiveHourlyRateUsesHourlyRateDirectlyWhenPaidHourly() {
        let settings = AppSettings.shared
        let originalType = settings.paymentType
        let originalRate = settings.hourlyRate
        defer { settings.paymentType = originalType; settings.hourlyRate = originalRate }

        settings.paymentType = .hourly
        settings.hourlyRate = 25
        #expect(settings.effectiveHourlyRate == 25)
    }

    @Test func effectiveHourlyRateDerivesFromMonthlySalaryOver160Hours() {
        let settings = AppSettings.shared
        let originalType = settings.paymentType
        let originalSalary = settings.monthlySalary
        defer { settings.paymentType = originalType; settings.monthlySalary = originalSalary }

        settings.paymentType = .monthly
        settings.monthlySalary = 4000
        #expect(settings.effectiveHourlyRate == 25) // 4000 / 160
    }

    @Test func dailyRateIsEffectiveHourlyRateTimesWorkDayHours() {
        let settings = AppSettings.shared
        let originalType = settings.paymentType
        let originalRate = settings.hourlyRate
        let originalHours = settings.workDayHours
        defer {
            settings.paymentType = originalType
            settings.hourlyRate = originalRate
            settings.workDayHours = originalHours
        }

        settings.paymentType = .hourly
        settings.hourlyRate = 20
        settings.workDayHours = 8
        #expect(settings.dailyRate == 160)
    }

    // MARK: - AppSettings: Office/Home schedule labels

    @Test func officeAndHomeDaysLabelsReflectCurrentSets() {
        let settings = AppSettings.shared
        let originalOffice = settings.officeDays
        let originalHome = settings.homeDays
        defer { settings.officeDays = originalOffice; settings.homeDays = originalHome }

        settings.officeDays = [2, 4] // Mon, Wed
        settings.homeDays = [3, 5]   // Tue, Thu

        #expect(settings.officeDaysLabel == "Mon, Wed")
        #expect(settings.homeDaysLabel == "Tue, Thu")
    }
}
