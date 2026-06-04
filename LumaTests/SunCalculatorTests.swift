import XCTest
@testable import Luma

final class SunCalculatorTests: XCTestCase {
    func testBoiseSunEventsAreOrdered() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!

        let events = SunCalculator.events(on: date, latitude: 43.6138, longitude: -116.3972, calendar: calendar)

        XCTAssertNotNil(events)
        XCTAssertLessThan(events!.sunrise, events!.sunset)
    }

    func testBoiseSunEventsAreInExpectedSummerLocalRanges() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!

        let events = try XCTUnwrap(SunCalculator.events(on: date, latitude: 43.6138, longitude: -116.3972, calendar: calendar))
        let sunriseHour = calendar.component(.hour, from: events.sunrise)
        let sunsetHour = calendar.component(.hour, from: events.sunset)

        XCTAssertTrue((5...7).contains(sunriseHour), "sunrise hour was \(sunriseHour)")
        XCTAssertTrue((20...22).contains(sunsetHour), "sunset hour was \(sunsetHour)")
    }

    func testBoiseSunEventsAreInExpectedWinterLocalRanges() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 12, day: 21, hour: 12))!

        let events = try XCTUnwrap(SunCalculator.events(on: date, latitude: 43.6138, longitude: -116.3972, calendar: calendar))
        let sunriseHour = calendar.component(.hour, from: events.sunrise)
        let sunsetHour = calendar.component(.hour, from: events.sunset)

        XCTAssertTrue((7...9).contains(sunriseHour), "sunrise hour was \(sunriseHour)")
        XCTAssertTrue((16...18).contains(sunsetHour), "sunset hour was \(sunsetHour)")
    }

    func testInvalidCoordinatesReturnNoSunEvents() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!

        XCTAssertNil(SunCalculator.events(on: date, latitude: 91, longitude: 0, calendar: calendar))
        XCTAssertNil(SunCalculator.events(on: date, latitude: 0, longitude: 181, calendar: calendar))
        XCTAssertNil(SunCalculator.events(on: date, latitude: .nan, longitude: 0, calendar: calendar))
        XCTAssertNil(SunCalculator.solarElevation(on: date, latitude: 91, longitude: 0, calendar: calendar))
    }

    func testPolarDayReturnsNoSunEvents() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!

        XCTAssertNil(SunCalculator.events(on: date, latitude: 80, longitude: 0, calendar: calendar))
    }

    func testSolarElevationTracksDayShape() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Boise")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!
        let events = try XCTUnwrap(SunCalculator.events(on: date, latitude: 43.6138, longitude: -116.3972, calendar: calendar))

        let noonElevation = try XCTUnwrap(SunCalculator.solarElevation(on: date, latitude: 43.6138, longitude: -116.3972, calendar: calendar))
        let sunsetElevation = try XCTUnwrap(SunCalculator.solarElevation(on: events.sunset, latitude: 43.6138, longitude: -116.3972, calendar: calendar))
        let nightElevation = try XCTUnwrap(SunCalculator.solarElevation(on: calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 2))!, latitude: 43.6138, longitude: -116.3972, calendar: calendar))

        XCTAssertGreaterThan(noonElevation, 55)
        XCTAssertEqual(sunsetElevation, -0.8, accuracy: 1.5)
        XCTAssertLessThan(nightElevation, -15)
    }
}
