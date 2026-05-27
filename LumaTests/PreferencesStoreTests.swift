import XCTest
@testable import Luma

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private let settingsKey = "LumaSettings.v1"
    private let presetProfileMigrationKey = "LumaSettings.presetProfilesRetuned.v3"
    private let launchAtLoginMigrationKey = "LumaSettings.launchAtLoginDefaulted.v2"

    func testBuiltInPresetProfilesRefreshOnFirstMigration() throws {
        let defaults = try makeDefaults()
        let oldBalanced = LumaSettings(
            selectedPreset: .balanced,
            day: DisplayProfile(kelvin: 2800, brightness: 100, dimOpacity: 0),
            night: DisplayProfile(kelvin: 1900, brightness: 85, dimOpacity: 10),
            sleep: DisplayProfile(kelvin: 3700, brightness: 80, dimOpacity: 20)
        )
        defaults.set(try JSONEncoder().encode(oldBalanced), forKey: settingsKey)

        let store = PreferencesStore(defaults: defaults)
        let balanced = try XCTUnwrap(LumaPreset.balanced.profiles)

        XCTAssertEqual(store.settings.day, balanced.day)
        XCTAssertEqual(store.settings.night, balanced.night)
        XCTAssertEqual(store.settings.sleep, balanced.sleep)
        XCTAssertTrue(defaults.bool(forKey: presetProfileMigrationKey))
    }

    func testCustomPresetProfilesAreNotMigrated() throws {
        let defaults = try makeDefaults()
        let custom = LumaSettings(
            selectedPreset: .custom,
            day: DisplayProfile(kelvin: 4300, brightness: 91, dimOpacity: 3),
            night: DisplayProfile(kelvin: 2900, brightness: 77, dimOpacity: 13),
            sleep: DisplayProfile(kelvin: 1800, brightness: 61, dimOpacity: 31)
        )
        defaults.set(try JSONEncoder().encode(custom), forKey: settingsKey)

        let store = PreferencesStore(defaults: defaults)

        XCTAssertEqual(store.settings.day, custom.day)
        XCTAssertEqual(store.settings.night, custom.night)
        XCTAssertEqual(store.settings.sleep, custom.sleep)
        XCTAssertTrue(defaults.bool(forKey: presetProfileMigrationKey))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "LumaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: launchAtLoginMigrationKey)
        return defaults
    }
}
