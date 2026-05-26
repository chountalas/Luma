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
        XCTAssertEqual(schedule.phase(at: polarSummer, calendar: calendar), .day)
        XCTAssertEqual(schedule.phase(at: date(hour: 22, minute: 0, calendar: calendar), calendar: calendar), .night)
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
