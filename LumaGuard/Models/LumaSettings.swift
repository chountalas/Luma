import Foundation

struct LumaSettings: Codable, Equatable {
    var day = DisplayProfile.dayDefault
    var night = DisplayProfile.nightDefault
    var sleep = DisplayProfile.sleepDefault
    var schedule = ScheduleSettings()
    var hotkeys = HotkeySettings.default
    var launchAtLogin = true
    var useOverlayFallback = true

    func profile(for phase: ActivePhase) -> DisplayProfile {
        switch phase {
        case .day: day
        case .night: night
        case .sleep: sleep
        case .paused: day
        }
    }
}
