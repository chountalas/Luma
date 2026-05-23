import Foundation

enum LumaPreset: String, Codable, CaseIterable, Identifiable {
    case barely
    case subtle
    case balanced
    case high
    case deep
    case reading
    case lateNight
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barely: "Barely"
        case .subtle: "Subtle"
        case .balanced: "Balanced"
        case .high: "High"
        case .deep: "Deep"
        case .reading: "Reading"
        case .lateNight: "Late Night"
        case .custom: "Custom"
        }
    }

    var detail: String {
        switch self {
        case .barely: "Almost neutral, light dimming"
        case .subtle: "Low warmth and dimming"
        case .balanced: "Daily default"
        case .high: "Clearer evening shift"
        case .deep: "Strong nighttime protection"
        case .reading: "Warm, paper-like evening tone"
        case .lateNight: "Very warm and dim for late work"
        case .custom: "Manual profile settings"
        }
    }

    var profiles: PresetProfiles? {
        switch self {
        case .barely:
            PresetProfiles(
                day: DisplayProfile(kelvin: 4800, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 3400, brightness: 96, dimOpacity: 2),
                sleep: DisplayProfile(kelvin: 2800, brightness: 88, dimOpacity: 8)
            )
        case .subtle:
            PresetProfiles(
                day: DisplayProfile(kelvin: 3600, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 2700, brightness: 92, dimOpacity: 5),
                sleep: DisplayProfile(kelvin: 2200, brightness: 82, dimOpacity: 14)
            )
        case .balanced:
            PresetProfiles(
                day: .dayDefault,
                night: .nightDefault,
                sleep: .sleepDefault
            )
        case .high:
            PresetProfiles(
                day: DisplayProfile(kelvin: 2600, brightness: 98, dimOpacity: 3),
                night: DisplayProfile(kelvin: 1650, brightness: 80, dimOpacity: 16),
                sleep: DisplayProfile(kelvin: 1350, brightness: 66, dimOpacity: 28)
            )
        case .deep:
            PresetProfiles(
                day: DisplayProfile(kelvin: 2500, brightness: 96, dimOpacity: 4),
                night: DisplayProfile(kelvin: 1500, brightness: 78, dimOpacity: 18),
                sleep: DisplayProfile(kelvin: 1200, brightness: 62, dimOpacity: 32)
            )
        case .reading:
            PresetProfiles(
                day: DisplayProfile(kelvin: 3200, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 2100, brightness: 86, dimOpacity: 12),
                sleep: DisplayProfile(kelvin: 1700, brightness: 72, dimOpacity: 24)
            )
        case .lateNight:
            PresetProfiles(
                day: DisplayProfile(kelvin: 2800, brightness: 94, dimOpacity: 4),
                night: DisplayProfile(kelvin: 1300, brightness: 70, dimOpacity: 28),
                sleep: DisplayProfile(kelvin: 1000, brightness: 50, dimOpacity: 42)
            )
        case .custom:
            nil
        }
    }
}

struct PresetProfiles: Equatable {
    var day: DisplayProfile
    var night: DisplayProfile
    var sleep: DisplayProfile
}
