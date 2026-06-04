import XCTest
@testable import Luma

final class ScheduleSettingsTests: XCTestCase {
    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDefaultScheduleUsesManualHoursWithoutSunCoordinates() {
        let schedule = ScheduleSettings()

        XCTAssertEqual(schedule.mode, .manual)
        XCTAssertFalse(schedule.hasValidSunCoordinates)
        XCTAssertEqual(schedule.dayNightTransitionSeconds, ScheduleSettings.defaultDayNightTransitionSeconds)
        XCTAssertEqual(schedule.phase(at: date(hour: 22, minute: 0), calendar: testCalendar), .night)
        XCTAssertEqual(schedule.phase(at: date(hour: 12, minute: 0), calendar: testCalendar), .day)
    }

    func testSleepOverridesNightAcrossMidnight() {
        var schedule = ScheduleSettings()
        schedule.mode = .manual
        schedule.sleepEnabled = true
        schedule.nightStart = TimeOfDay(hour: 20, minute: 0)
        schedule.nightEnd = TimeOfDay(hour: 6, minute: 0)
        schedule.bedtime = TimeOfDay(hour: 0, minute: 0)
        schedule.wakeTime = TimeOfDay(hour: 4, minute: 0)

        XCTAssertEqual(schedule.phase(at: date(hour: 1, minute: 30), calendar: testCalendar), .sleep)
        XCTAssertEqual(schedule.phase(at: date(hour: 22, minute: 0), calendar: testCalendar), .night)
        XCTAssertEqual(schedule.phase(at: date(hour: 10, minute: 0), calendar: testCalendar), .day)
    }

    func testDisabledSleepFallsBackToNight() {
        var schedule = ScheduleSettings()
        schedule.mode = .manual
        schedule.sleepEnabled = false

        XCTAssertEqual(schedule.phase(at: date(hour: 1, minute: 30), calendar: testCalendar), .night)
    }

    func testSunScheduleUsesSunsetToSunrise() {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = false
        schedule.latitude = 43.6138
        schedule.longitude = -116.3972
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!

        XCTAssertEqual(schedule.phase(at: date(hour: 12, minute: 0, calendar: calendar), calendar: calendar), .day)
        XCTAssertEqual(schedule.phase(at: date(hour: 4, minute: 0, calendar: calendar), calendar: calendar), .night)
    }

    func testSunScheduleSwitchesAtSunriseAndSunsetBoundaries() throws {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = false
        schedule.latitude = 43.6138
        schedule.longitude = -116.3972
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let testDate = date(hour: 12, minute: 0, calendar: calendar)
        let events = try XCTUnwrap(schedule.sunEvents(on: testDate, calendar: calendar))

        XCTAssertEqual(schedule.phase(at: events.sunrise.addingTimeInterval(-60), calendar: calendar), .night)
        XCTAssertEqual(schedule.phase(at: events.sunrise.addingTimeInterval(60), calendar: calendar), .day)
        XCTAssertEqual(schedule.phase(at: events.sunset.addingTimeInterval(-60), calendar: calendar), .day)
        XCTAssertEqual(schedule.phase(at: events.sunset.addingTimeInterval(60), calendar: calendar), .night)
    }

    func testManualDayNightTransitionsAreCenteredOnBoundaries() throws {
        var schedule = ScheduleSettings()
        schedule.mode = .manual
        schedule.sleepEnabled = false
        schedule.nightStart = TimeOfDay(hour: 20, minute: 0)
        schedule.nightEnd = TimeOfDay(hour: 6, minute: 0)
        schedule.dayNightTransitionSeconds = 14_400

        let beforeSunset = try XCTUnwrap(schedule.phaseTransition(at: date(hour: 19, minute: 0), calendar: testCalendar))
        let atSunset = try XCTUnwrap(schedule.phaseTransition(at: date(hour: 20, minute: 0), calendar: testCalendar))
        let afterSunset = try XCTUnwrap(schedule.phaseTransition(at: date(hour: 21, minute: 0), calendar: testCalendar))

        XCTAssertEqual(beforeSunset.from, .day)
        XCTAssertEqual(beforeSunset.to, .night)
        XCTAssertEqual(beforeSunset.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(atSunset.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(afterSunset.progress, 0.75, accuracy: 0.001)
        XCTAssertNil(schedule.phaseTransition(at: date(hour: 17, minute: 59), calendar: testCalendar))
    }

    func testScheduledProfileBlendsAcrossTransitionWindow() {
        var schedule = ScheduleSettings()
        schedule.mode = .manual
        schedule.sleepEnabled = false
        schedule.nightStart = TimeOfDay(hour: 20, minute: 0)
        schedule.nightEnd = TimeOfDay(hour: 6, minute: 0)
        schedule.dayNightTransitionSeconds = 14_400
        let settings = LumaSettings(
            day: DisplayProfile(kelvin: 5000, brightness: 100, dimOpacity: 0),
            night: DisplayProfile(kelvin: 3000, brightness: 90, dimOpacity: 10),
            sleep: DisplayProfile(kelvin: 2000, brightness: 80, dimOpacity: 20),
            schedule: schedule
        )

        let profile = settings.scheduledProfile(at: date(hour: 19, minute: 0), calendar: testCalendar)

        XCTAssertEqual(profile.phase, .day)
        XCTAssertEqual(profile.profile.kelvin, 4500, accuracy: 0.001)
        XCTAssertEqual(profile.profile.brightness, 97.5, accuracy: 0.001)
        XCTAssertEqual(profile.profile.dimOpacity, 2.5, accuracy: 0.001)
    }

    func testSunScheduleUsesSolarElevationForContinuousProfiles() throws {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = false
        schedule.latitude = 43.6138
        schedule.longitude = -116.3972
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 2))!
        let events = try XCTUnwrap(schedule.sunEvents(on: day, calendar: calendar))
        let settings = LumaSettings(
            day: DisplayProfile(kelvin: 5000, brightness: 100, dimOpacity: 0),
            night: DisplayProfile(kelvin: 3000, brightness: 90, dimOpacity: 10),
            sleep: DisplayProfile(kelvin: 2000, brightness: 80, dimOpacity: 20),
            schedule: schedule
        )

        XCTAssertTrue(schedule.usesSolarCurve(at: day, calendar: calendar))

        let middayProfile = settings.scheduledProfile(at: day, calendar: calendar)
        let sunsetProfile = settings.scheduledProfile(at: events.sunset, calendar: calendar)
        let nightProfile = settings.scheduledProfile(at: night, calendar: calendar)

        XCTAssertEqual(middayProfile.profile.kelvin, 5000, accuracy: 1)
        XCTAssertLessThan(sunsetProfile.profile.kelvin, 3400)
        XCTAssertGreaterThan(sunsetProfile.profile.kelvin, 3000)
        XCTAssertEqual(nightProfile.profile.kelvin, 3000, accuracy: 1)
    }

    func testSunScheduledProfileUsesSleepProfileDuringSleepWindow() {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = true
        schedule.latitude = 43.6138
        schedule.longitude = -116.3972
        schedule.bedtime = TimeOfDay(hour: 0, minute: 0)
        schedule.wakeTime = TimeOfDay(hour: 4, minute: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let sleepDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 2))!
        let settings = LumaSettings(
            day: DisplayProfile(kelvin: 5000, brightness: 100, dimOpacity: 0),
            night: DisplayProfile(kelvin: 3000, brightness: 90, dimOpacity: 10),
            sleep: DisplayProfile(kelvin: 2000, brightness: 80, dimOpacity: 20),
            schedule: schedule
        )

        let scheduledProfile = settings.scheduledProfile(at: sleepDate, calendar: calendar)

        XCTAssertEqual(scheduledProfile.phase, .sleep)
        XCTAssertEqual(scheduledProfile.profile, settings.sleep)
    }

    func testSolarNightProgressIncreasesAsSunDrops() throws {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = false
        schedule.latitude = 43.6138
        schedule.longitude = -116.3972
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!
        let events = try XCTUnwrap(schedule.sunEvents(on: day, calendar: calendar))
        let beforeSunset = try XCTUnwrap(calendar.date(byAdding: .hour, value: -1, to: events.sunset))
        let afterSunset = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: events.sunset))

        let beforeProgress = try XCTUnwrap(schedule.solarNightProgress(at: beforeSunset, calendar: calendar))
        let sunsetProgress = try XCTUnwrap(schedule.solarNightProgress(at: events.sunset, calendar: calendar))
        let afterProgress = try XCTUnwrap(schedule.solarNightProgress(at: afterSunset, calendar: calendar))

        XCTAssertLessThan(beforeProgress, sunsetProgress)
        XCTAssertLessThan(sunsetProgress, afterProgress)
        XCTAssertGreaterThan(sunsetProgress, 0.75)
        XCTAssertLessThan(sunsetProgress, 1)
    }

    func testSunScheduleFallsBackToManualHoursWhenCoordinatesAreInvalid() {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = false
        schedule.latitude = 200
        schedule.longitude = -116.3972
        schedule.nightStart = TimeOfDay(hour: 20, minute: 0)
        schedule.nightEnd = TimeOfDay(hour: 6, minute: 0)

        XCTAssertFalse(schedule.hasValidSunCoordinates)
        XCTAssertNil(schedule.sunEvents(on: date(hour: 12, minute: 0), calendar: testCalendar))
        XCTAssertFalse(schedule.usesSolarCurve(at: date(hour: 12, minute: 0), calendar: testCalendar))
        XCTAssertNil(schedule.solarNightProgress(at: date(hour: 12, minute: 0), calendar: testCalendar))
        XCTAssertEqual(schedule.phase(at: date(hour: 22, minute: 0), calendar: testCalendar), .night)
        XCTAssertEqual(schedule.phase(at: date(hour: 12, minute: 0), calendar: testCalendar), .day)
    }

    func testSunScheduleFallsBackToManualHoursWhenSunEventIsUnavailable() {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = false
        schedule.latitude = 80
        schedule.longitude = 0
        schedule.nightStart = TimeOfDay(hour: 20, minute: 0)
        schedule.nightEnd = TimeOfDay(hour: 6, minute: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let polarSummer = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!

        XCTAssertNil(schedule.sunEvents(on: polarSummer, calendar: calendar))
        XCTAssertFalse(schedule.usesSolarCurve(at: polarSummer, calendar: calendar))
        XCTAssertNil(schedule.solarNightProgress(at: polarSummer, calendar: calendar))
        XCTAssertEqual(schedule.phase(at: polarSummer, calendar: calendar), .day)
        XCTAssertEqual(schedule.phase(at: date(hour: 22, minute: 0, calendar: calendar), calendar: calendar), .night)
    }

    func testScheduledProfileUsesManualFallbackWhenSunEventIsUnavailable() {
        var schedule = ScheduleSettings()
        schedule.mode = .sun
        schedule.sleepEnabled = false
        schedule.latitude = 80
        schedule.longitude = 0
        schedule.nightStart = TimeOfDay(hour: 20, minute: 0)
        schedule.nightEnd = TimeOfDay(hour: 6, minute: 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let polarSummer = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!
        let settings = LumaSettings(
            day: DisplayProfile(kelvin: 5000, brightness: 100, dimOpacity: 0),
            night: DisplayProfile(kelvin: 3000, brightness: 90, dimOpacity: 10),
            sleep: DisplayProfile(kelvin: 2000, brightness: 80, dimOpacity: 20),
            schedule: schedule
        )

        let scheduledProfile = settings.scheduledProfile(at: polarSummer, calendar: calendar)

        XCTAssertEqual(scheduledProfile.phase, .day)
        XCTAssertEqual(scheduledProfile.profile, settings.day)
    }

    private func date(hour: Int, minute: Int, calendar: Calendar? = nil) -> Date {
        let calendar = calendar ?? testCalendar
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 23
        components.hour = hour
        components.minute = minute
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
