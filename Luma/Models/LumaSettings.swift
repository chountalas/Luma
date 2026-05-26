import Foundation

struct LumaSettings: Codable, Equatable {
    var selectedPreset: LumaPreset = .balanced
    var day = DisplayProfile.dayDefault
    var night = DisplayProfile.nightDefault
    var sleep = DisplayProfile.sleepDefault
    var schedule = ScheduleSettings()
    var hotkeys = HotkeySettings.default
    var launchAtLogin = true
    var useOverlayFallback = true

    init() {}

    init(
        selectedPreset: LumaPreset = .balanced,
        day: DisplayProfile = .dayDefault,
        night: DisplayProfile = .nightDefault,
        sleep: DisplayProfile = .sleepDefault,
        schedule: ScheduleSettings = ScheduleSettings(),
        hotkeys: HotkeySettings = .default,
        launchAtLogin: Bool = true,
        useOverlayFallback: Bool = true
    ) {
        self.selectedPreset = selectedPreset
        self.day = day
        self.night = night
        self.sleep = sleep
        self.schedule = schedule
        self.hotkeys = hotkeys
        self.launchAtLogin = launchAtLogin
        self.useOverlayFallback = useOverlayFallback
    }

    private enum CodingKeys: String, CodingKey {
        case selectedPreset
        case day
        case night
        case sleep
        case schedule
        case hotkeys
        case launchAtLogin
        case useOverlayFallback
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPreset = try container.decodeIfPresent(LumaPreset.self, forKey: .selectedPreset) ?? .balanced
        day = try container.decodeIfPresent(DisplayProfile.self, forKey: .day) ?? .dayDefault
        night = try container.decodeIfPresent(DisplayProfile.self, forKey: .night) ?? .nightDefault
        sleep = try container.decodeIfPresent(DisplayProfile.self, forKey: .sleep) ?? .sleepDefault
        schedule = try container.decodeIfPresent(ScheduleSettings.self, forKey: .schedule) ?? ScheduleSettings()
        hotkeys = try container.decodeIfPresent(HotkeySettings.self, forKey: .hotkeys) ?? .default
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        useOverlayFallback = try container.decodeIfPresent(Bool.self, forKey: .useOverlayFallback) ?? true
    }

    func profile(for phase: ActivePhase) -> DisplayProfile {
        switch phase {
        case .day: day
        case .night: night
        case .sleep: sleep
        case .paused: day
        }
    }
}
