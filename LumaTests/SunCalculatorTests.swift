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
}
