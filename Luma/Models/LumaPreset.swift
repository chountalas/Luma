import Foundation

enum LumaPreset: String, Codable, CaseIterable, Identifiable {
    case clear
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
        case .clear: "Clear"
        case .barely: "Light"
        case .subtle: "Subtle"
        case .balanced: "Balanced"
        case .high: "Strong"
        case .deep: "Deep"
        case .reading: "Reading"
        case .lateNight: "Late Night"
        case .custom: "Custom"
        }
    }

    var detail: String {
        switch self {
        case .clear: "Near-neutral with no dimming"
        case .barely: "Light evening warmth"
        case .subtle: "Soft warmth and mild dimming"
        case .balanced: "Daily default"
        case .high: "Strong evening warmth"
        case .deep: "Strong nighttime protection"
        case .reading: "Warm, paper-like evening tone"
        case .lateNight: "Very warm and dim for late work"
        case .custom: "Manual profile settings"
        }
    }

    var profiles: PresetProfiles? {
        switch self {
        case .clear:
            PresetProfiles(
                day: DisplayProfile(kelvin: 6500, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 5000, brightness: 100, dimOpacity: 0),
                sleep: DisplayProfile(kelvin: 3600, brightness: 95, dimOpacity: 2)
            )
        case .barely:
            PresetProfiles(
                day: DisplayProfile(kelvin: 5600, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 4200, brightness: 98, dimOpacity: 1),
                sleep: DisplayProfile(kelvin: 3200, brightness: 94, dimOpacity: 4)
            )
        case .subtle:
            PresetProfiles(
                day: DisplayProfile(kelvin: 4700, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 3400, brightness: 95, dimOpacity: 4),
                sleep: DisplayProfile(kelvin: 2600, brightness: 88, dimOpacity: 10)
            )
        case .balanced:
            PresetProfiles(
                day: .dayDefault,
                night: .nightDefault,
                sleep: .sleepDefault
            )
        case .high:
            PresetProfiles(
                day: DisplayProfile(kelvin: 3000, brightness: 98, dimOpacity: 2),
                night: DisplayProfile(kelvin: 1900, brightness: 82, dimOpacity: 16),
                sleep: DisplayProfile(kelvin: 1500, brightness: 68, dimOpacity: 28)
            )
        case .deep:
            PresetProfiles(
                day: DisplayProfile(kelvin: 2600, brightness: 96, dimOpacity: 4),
                night: DisplayProfile(kelvin: 1500, brightness: 74, dimOpacity: 24),
                sleep: DisplayProfile(kelvin: 1200, brightness: 58, dimOpacity: 38)
            )
        case .reading:
            PresetProfiles(
                day: DisplayProfile(kelvin: 3600, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 2400, brightness: 86, dimOpacity: 12),
                sleep: DisplayProfile(kelvin: 1900, brightness: 72, dimOpacity: 24)
            )
        case .lateNight:
            PresetProfiles(
                day: DisplayProfile(kelvin: 2400, brightness: 92, dimOpacity: 6),
                night: DisplayProfile(kelvin: 1300, brightness: 66, dimOpacity: 32),
                sleep: DisplayProfile(kelvin: 1000, brightness: 45, dimOpacity: 50)
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
