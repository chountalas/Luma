import XCTest
@testable import Luma

final class ColorTemperatureTests: XCTestCase {
    func testWarmTemperatureReducesBlueChannel() {
        let warm = ColorTemperature.rgbMultipliers(kelvin: 1900)
        let neutral = ColorTemperature.rgbMultipliers(kelvin: 6500)

        XCTAssertGreaterThan(warm.red, 0.9)
        XCTAssertLessThan(warm.blue, neutral.blue)
    }

    func testGammaTablesRespectSampleCount() {
        let tables = ColorTemperature.gammaTables(profile: .nightDefault, samples: 32)

        XCTAssertEqual(tables.red.count, 32)
        XCTAssertEqual(tables.green.count, 32)
        XCTAssertEqual(tables.blue.count, 32)
    }
}
