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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.loadSettings(defaults: defaults, key: settingsKey)
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

        settings.selectedPreset = preset
        settings.day = profiles.day
        settings.night = profiles.night
        settings.sleep = profiles.sleep
    }

    func markCustomPreset() {
        if settings.selectedPreset != .custom {
            settings.selectedPreset = .custom
        }
    }

    func nudgeCurrentKelvin(by delta: Double) {
        let phase = settings.schedule.phase(at: Date())
        switch phase {
        case .day:
            settings.day.kelvin = clamped(settings.day.kelvin + delta, 1000, 10000)
        case .night:
            settings.night.kelvin = clamped(settings.night.kelvin + delta, 1000, 10000)
        case .sleep:
            settings.sleep.kelvin = clamped(settings.sleep.kelvin + delta, 1000, 10000)
        case .paused:
            break
        }
    }

    func nudgeCurrentBrightness(by delta: Double) {
        let phase = settings.schedule.phase(at: Date())
        switch phase {
        case .day:
            settings.day.brightness = clamped(settings.day.brightness + delta, 5, 150)
        case .night:
            settings.night.brightness = clamped(settings.night.brightness + delta, 5, 150)
        case .sleep:
            settings.sleep.brightness = clamped(settings.sleep.brightness + delta, 5, 150)
        case .paused:
            break
        }
    }

    func importSafeIrisPreferences() -> Bool {
        let url = URL(fileURLWithPath: "/Users/connorhountalas/Library/Preferences/com.iristech.Iris.plist")
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

    private static func loadSettings(defaults: UserDefaults, key: String) -> LumaSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(LumaSettings.self, from: data) else {
            return LumaSettings()
        }
        return decoded
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
