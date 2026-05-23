import XCTest
@testable import Luma

final class LumaPresetTests: XCTestCase {
    func testPresetProfilesChangeStrength() {
        let subtle = LumaPreset.subtle.profiles!
        let balanced = LumaPreset.balanced.profiles!
        let deep = LumaPreset.deep.profiles!

        XCTAssertGreaterThan(subtle.night.kelvin, balanced.night.kelvin)
        XCTAssertGreaterThan(balanced.night.kelvin, deep.night.kelvin)
        XCTAssertLessThan(subtle.night.dimOpacity, balanced.night.dimOpacity)
        XCTAssertLessThan(balanced.night.dimOpacity, deep.night.dimOpacity)
    }

    func testOldSettingsDecodeWithBalancedPreset() throws {
        let data = """
        {
          "day": { "kelvin": 3100, "brightness": 100, "dimOpacity": 1 },
          "night": { "kelvin": 2100, "brightness": 88, "dimOpacity": 12 },
          "sleep": { "kelvin": 1700, "brightness": 70, "dimOpacity": 25 },
          "launchAtLogin": false,
          "useOverlayFallback": true
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(LumaSettings.self, from: data)

        XCTAssertEqual(settings.selectedPreset, .balanced)
        XCTAssertEqual(settings.night.kelvin, 2100)
        XCTAssertFalse(settings.launchAtLogin)
    }
}
