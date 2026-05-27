import Foundation
import ServiceManagement

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var settings: LumaSettings {
        didSet {
            save()
            syncLaunchAtLogin()
            onChange?(settings)
        }
    }

    var onChange: ((LumaSettings) -> Void)?

    private let defaults: UserDefaults
    private let settingsKey = "LumaSettings.v1"
    private let launchAtLoginMigrationKey = "LumaSettings.launchAtLoginDefaulted.v2"
    private let presetProfileMigrationKey = "LumaSettings.presetProfilesRetuned.v3"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loadedSettings = Self.loadSettings(defaults: defaults, key: settingsKey)
        self.settings = loadedSettings.settings
        if !defaults.bool(forKey: presetProfileMigrationKey) {
            if loadedSettings.hasStoredSelectedPreset {
                settings = Self.refreshSelectedPresetProfiles(settings)
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

    func nudgeCurrentKelvin(by delta: Double) {
        var updated = settings
        let phase = settings.schedule.phase(at: Date())
        switch phase {
        case .day:
            updated.day.kelvin = clamped(updated.day.kelvin + delta, 1000, 10000)
        case .night:
            updated.night.kelvin = clamped(updated.night.kelvin + delta, 1000, 10000)
        case .sleep:
            updated.sleep.kelvin = clamped(updated.sleep.kelvin + delta, 1000, 10000)
        case .paused:
            return
        }
        updated.selectedPreset = .custom
        settings = updated
    }

    func nudgeCurrentBrightness(by delta: Double) {
        var updated = settings
        let phase = settings.schedule.phase(at: Date())
        switch phase {
        case .day:
            updated.day.brightness = clamped(updated.day.brightness + delta, 5, 150)
        case .night:
            updated.night.brightness = clamped(updated.night.brightness + delta, 5, 150)
        case .sleep:
            updated.sleep.brightness = clamped(updated.sleep.brightness + delta, 5, 150)
        case .paused:
            return
        }
        updated.selectedPreset = .custom
        settings = updated
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
        imported.schedule.pauseTransitionSeconds = (double(from: plist["PauseTransitionDuration"]) ?? 1000) / 1000

        settings = imported
        settings.selectedPreset = .custom
        return true
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    private static func loadSettings(defaults: UserDefaults, key: String) -> LoadedSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(LumaSettings.self, from: data) else {
            return LoadedSettings(settings: LumaSettings(), hasStoredSelectedPreset: false)
        }

        let storedObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return LoadedSettings(
            settings: decoded,
            hasStoredSelectedPreset: storedObject?["selectedPreset"] != nil
        )
    }

    private static func refreshSelectedPresetProfiles(_ settings: LumaSettings) -> LumaSettings {
        guard let profiles = settings.selectedPreset.profiles else {
            return settings
        }

        var migrated = settings
        migrated.day = profiles.day
        migrated.night = profiles.night
        migrated.sleep = profiles.sleep
        return migrated
    }

    private func syncLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Launch-at-login can fail in unsigned development builds; keep the preference visible.
        }
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

    private func clamped(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}

private struct LoadedSettings {
    var settings: LumaSettings
    var hasStoredSelectedPreset: Bool
}
