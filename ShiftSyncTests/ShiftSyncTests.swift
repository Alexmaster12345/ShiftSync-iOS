//
//  ShiftSyncTests.swift
//  ShiftSyncTests
//

import Testing
import Foundation
@testable import ShiftSync

// AppSettings and ShiftStore's underlying storage is UserDefaults.standard, shared with
// whatever app/simulator hosts this test bundle. Tests run serialized (not in parallel)
// and each one restores the settings it touches, so they don't leak state into each
// other or into the real app if run on a device that also has ShiftSync installed.
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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

        let store = ShiftStore()
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
        let store = ShiftStore()
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
        let store = ShiftStore()
        store.clearAll()
        defer { store.clearAll() }

        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        store.addEntry(ShiftEntry(shiftType: .regular, startedAt: morning, durationMinutes: 60, unpaidBreakMinutes: 0))

        #expect(store.hasShifts(on: Date()))
    }
}
