import XCTest
@testable import Luma

final class LumaPresetTests: XCTestCase {
    func testPresetProfilesChangeStrength() {
        let clear = LumaPreset.clear.profiles!
        let barely = LumaPreset.barely.profiles!
        let subtle = LumaPreset.subtle.profiles!
        let balanced = LumaPreset.balanced.profiles!
        let high = LumaPreset.high.profiles!
        let deep = LumaPreset.deep.profiles!

        XCTAssertGreaterThan(clear.night.kelvin, barely.night.kelvin)
        XCTAssertGreaterThan(barely.night.kelvin, subtle.night.kelvin)
        XCTAssertGreaterThan(subtle.night.kelvin, balanced.night.kelvin)
        XCTAssertGreaterThan(balanced.night.kelvin, high.night.kelvin)
        XCTAssertGreaterThan(high.night.kelvin, deep.night.kelvin)
        XCTAssertLessThanOrEqual(clear.night.dimOpacity, barely.night.dimOpacity)
        XCTAssertLessThan(barely.night.dimOpacity, subtle.night.dimOpacity)
        XCTAssertLessThan(subtle.night.dimOpacity, balanced.night.dimOpacity)
        XCTAssertLessThan(balanced.night.dimOpacity, high.night.dimOpacity)
        XCTAssertLessThan(high.night.dimOpacity, deep.night.dimOpacity)
    }

    func testPresetProfilesStayInsideDisplayLimits() {
        XCTAssertGreaterThanOrEqual(LumaPreset.allCases.count, 9)

        for preset in LumaPreset.allCases where preset != .custom {
            let profiles = preset.profiles!
            for profile in [profiles.day, profiles.night, profiles.sleep] {
                XCTAssertGreaterThanOrEqual(profile.kelvin, 1000)
                XCTAssertLessThanOrEqual(profile.kelvin, 10000)
                XCTAssertGreaterThanOrEqual(profile.brightness, 5)
                XCTAssertLessThanOrEqual(profile.brightness, 150)
                XCTAssertGreaterThanOrEqual(profile.dimOpacity, 0)
                XCTAssertLessThanOrEqual(profile.dimOpacity, 85)
            }
        }
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

    func testOldPresetNamesStillDecode() throws {
        for preset in [LumaPreset.subtle, .balanced, .deep, .custom] {
            let data = #"{"selectedPreset":"\#(preset.rawValue)"}"#.data(using: .utf8)!
            let settings = try JSONDecoder().decode(LumaSettings.self, from: data)

            XCTAssertEqual(settings.selectedPreset, preset)
        }
    }
}
