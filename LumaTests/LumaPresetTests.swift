import XCTest
@testable import Luma

final class LumaPresetTests: XCTestCase {
    func testPresetProfilesChangeStrength() {
        let presets: [LumaPreset] = [.clear, .barely, .subtle, .balanced, .high, .deep]
        let profiles = presets.map { $0.profiles! }

        for index in 1..<profiles.count {
            XCTAssertGreaterThan(profiles[index - 1].day.kelvin, profiles[index].day.kelvin)
            XCTAssertGreaterThan(profiles[index - 1].night.kelvin, profiles[index].night.kelvin)
            XCTAssertGreaterThan(profiles[index - 1].sleep.kelvin, profiles[index].sleep.kelvin)
            XCTAssertLessThanOrEqual(profiles[index - 1].day.dimOpacity, profiles[index].day.dimOpacity)
            XCTAssertLessThan(profiles[index - 1].night.dimOpacity, profiles[index].night.dimOpacity)
            XCTAssertLessThan(profiles[index - 1].sleep.dimOpacity, profiles[index].sleep.dimOpacity)
        }
    }

    func testEachPresetGetsWarmerThroughPhases() {
        for preset in LumaPreset.allCases where preset != .custom {
            let profiles = preset.profiles!

            XCTAssertGreaterThan(profiles.day.kelvin, profiles.night.kelvin)
            XCTAssertGreaterThan(profiles.night.kelvin, profiles.sleep.kelvin)
            XCTAssertLessThanOrEqual(profiles.day.dimOpacity, profiles.night.dimOpacity)
            XCTAssertLessThan(profiles.night.dimOpacity, profiles.sleep.dimOpacity)
        }
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
