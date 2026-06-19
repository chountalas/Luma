import Foundation
import ServiceManagement
import os

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var settings: LumaSettings {
        didSet {
            save()
            syncLaunchAtLogin()
            onChange?(settings)
        }
    }

    /// True when the user wants launch-at-login but macOS is holding the login
    /// item in "requires approval" — surfaced in Settings so it isn't a silent failure.
    @Published private(set) var loginItemNeedsApproval = false

    var onChange: ((LumaSettings) -> Void)?

    private let logger = Logger(subsystem: "com.connorhountalas.Luma", category: "preferences")

    private let defaults: UserDefaults
    private let settingsKey = "LumaSettings.v1"
    private let launchAtLoginMigrationKey = "LumaSettings.launchAtLoginDefaulted.v2"
    private let presetProfileMigrationKey = "LumaSettings.presetProfilesRetuned.v4"
    private static let legacyTransitionSeconds: Double = 3_600

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loadedSettings = Self.loadSettings(defaults: defaults, key: settingsKey)
        self.settings = loadedSettings.settings
        if !defaults.bool(forKey: presetProfileMigrationKey) {
            if loadedSettings.hasStoredSelectedPreset {
                settings = Self.refreshSelectedPresetProfilesAndTransitionDefaults(settings)
            }
            defaults.set(true, forKey: presetProfileMigrationKey)
            save()
        }
        if !defaults.bool(forKey: launchAtLoginMigrationKey) {
            settings.launchAtLogin = true
            defaults.set(true, forKey: launchAtLoginMigrationKey)
            save()
        }
        syncLaunchAtLogin()
    }

    func resetToDefaults() {
        settings = LumaSettings()
    }

    func applyPreset(_ preset: LumaPreset) {
        guard let profiles = preset.profiles else {
            settings.selectedPreset = .custom
            return
        }

        var updated = settings
        updated.selectedPreset = preset
        updated.day = profiles.day
        updated.night = profiles.night
        updated.sleep = profiles.sleep
        settings = updated
    }

    func markCustomPreset() {
        if settings.selectedPreset != .custom {
            settings.selectedPreset = .custom
        }
    }

    func importSafeIrisPreferences() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.iristech.Iris.plist")
        guard let plist = NSDictionary(contentsOf: url) as? [String: Any] else {
            return false
        }

        var imported = settings
        imported.day.kelvin = double(from: plist["DayTemperature"]) ?? imported.day.kelvin
        imported.day.brightness = double(from: plist["DayBrightness"]) ?? imported.day.brightness
        imported.day.dimOpacity = double(from: plist["DayDim"]) ?? imported.day.dimOpacity

        imported.night.kelvin = double(from: plist["NightTemperature"]) ?? imported.night.kelvin
        imported.night.brightness = double(from: plist["NightBrightness"]) ?? imported.night.brightness
        imported.night.dimOpacity = double(from: plist["NightDim"]) ?? imported.night.dimOpacity

        imported.sleep.kelvin = double(from: plist["SleepLight"]) ?? imported.sleep.kelvin
        imported.sleep.brightness = double(from: plist["SleepBrightness"]) ?? imported.sleep.brightness

        if let hour = int(from: plist["NightStartTimeHours"]), let minute = int(from: plist["NightStartTimeMinutes"]) {
            imported.schedule.nightStart = TimeOfDay(hour: hour, minute: minute)
        }
        if let hour = int(from: plist["NightEndTimeHours"]), let minute = int(from: plist["NightEndTimeMinutes"]) {
            imported.schedule.nightEnd = TimeOfDay(hour: hour, minute: minute)
        }
        if let hour = int(from: plist["BedtimeHours"]), let minute = int(from: plist["BedtimeMinutes"]) {
            imported.schedule.bedtime = TimeOfDay(hour: hour, minute: minute)
        }
        if let hour = int(from: plist["WakeTimeHours"]), let minute = int(from: plist["WakeTimeMinutes"]) {
            imported.schedule.wakeTime = TimeOfDay(hour: hour, minute: minute)
        }
        imported.schedule.latitude = double(from: plist["Latitude"]) ?? imported.schedule.latitude
        imported.schedule.longitude = double(from: plist["Longitude"]) ?? imported.schedule.longitude
        imported.schedule.mode = .sun

        imported.schedule.sleepEnabled = bool(from: plist["UseSleepLight"]) ?? imported.schedule.sleepEnabled
        imported.schedule.dayNightTransitionSeconds = double(from: plist["NightTransitionDuration"]) ?? imported.schedule.dayNightTransitionSeconds
        imported.schedule.sleepTransitionSeconds = double(from: plist["SleepTransitionDuration"]) ?? imported.schedule.sleepTransitionSeconds

        settings = imported
        settings.selectedPreset = .custom
        return true
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: settingsKey)
        } catch {
            logger.error("Failed to persist settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func loadSettings(defaults: UserDefaults, key: String) -> LoadedSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(LumaSettings.self, from: data) else {
            return LoadedSettings(settings: LumaSettings(), hasStoredSelectedPreset: false)
        }

        let probe = try? JSONDecoder().decode(SelectedPresetProbe.self, from: data)
        return LoadedSettings(
            settings: decoded,
            hasStoredSelectedPreset: probe?.hasSelectedPreset ?? false
        )
    }

    private static func refreshSelectedPresetProfilesAndTransitionDefaults(_ settings: LumaSettings) -> LumaSettings {
        guard let profiles = settings.selectedPreset.profiles else {
            return settings
        }

        var migrated = settings
        migrated.day = profiles.day
        migrated.night = profiles.night
        migrated.sleep = profiles.sleep
        if migrated.schedule.dayNightTransitionSeconds == legacyTransitionSeconds {
            migrated.schedule.dayNightTransitionSeconds = ScheduleSettings.defaultDayNightTransitionSeconds
        }
        if migrated.schedule.sleepTransitionSeconds == legacyTransitionSeconds {
            migrated.schedule.sleepTransitionSeconds = ScheduleSettings.defaultSleepTransitionSeconds
        }
        return migrated
    }

    private func syncLaunchAtLogin() {
        // Dev builds (DerivedData, dist/staging) must not touch the login item
        // record: registering from a transient path points launchd at a copy that
        // later disappears or goes stale, which breaks launch at startup.
        guard Self.isRunningFromApplicationsFolder else {
            logger.info("Skipping login item sync; bundle is outside /Applications: \(Bundle.main.bundlePath, privacy: .public)")
            return
        }

        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Login item sync failed (status \(SMAppService.mainApp.status.rawValue)): \(error.localizedDescription, privacy: .public)")
        }

        loginItemNeedsApproval = settings.launchAtLogin
            && SMAppService.mainApp.status == .requiresApproval
    }

    func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static var isRunningFromApplicationsFolder: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    private func double(from value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private func int(from value: Any?) -> Int? {
        double(from: value).map { Int($0) }
    }

    private func bool(from value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber:
            return number.boolValue
        case let bool as Bool:
            return bool
        default:
            return nil
        }
    }
}

private struct LoadedSettings {
    var settings: LumaSettings
    var hasStoredSelectedPreset: Bool
}

/// Detects whether stored settings JSON carried a `selectedPreset` key, which
/// separates pre-preset installs from current ones during first-run migration.
private struct SelectedPresetProbe: Decodable {
    let hasSelectedPreset: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasSelectedPreset = container.contains(.selectedPreset)
    }

    private enum CodingKeys: String, CodingKey {
        case selectedPreset
    }
}
