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
                night: DisplayProfile(kelvin: 6000, brightness: 100, dimOpacity: 0),
                sleep: DisplayProfile(kelvin: 5200, brightness: 98, dimOpacity: 1)
            )
        case .barely:
            PresetProfiles(
                day: DisplayProfile(kelvin: 5800, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 5300, brightness: 99, dimOpacity: 1),
                sleep: DisplayProfile(kelvin: 4600, brightness: 96, dimOpacity: 3)
            )
        case .subtle:
            PresetProfiles(
                day: DisplayProfile(kelvin: 5100, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 4600, brightness: 98, dimOpacity: 2),
                sleep: DisplayProfile(kelvin: 3900, brightness: 94, dimOpacity: 6)
            )
        case .balanced:
            PresetProfiles(
                day: .dayDefault,
                night: .nightDefault,
                sleep: .sleepDefault
            )
        case .high:
            PresetProfiles(
                day: DisplayProfile(kelvin: 3600, brightness: 99, dimOpacity: 1),
                night: DisplayProfile(kelvin: 3000, brightness: 92, dimOpacity: 7),
                sleep: DisplayProfile(kelvin: 2500, brightness: 84, dimOpacity: 16)
            )
        case .deep:
            PresetProfiles(
                day: DisplayProfile(kelvin: 3000, brightness: 97, dimOpacity: 3),
                night: DisplayProfile(kelvin: 2400, brightness: 86, dimOpacity: 13),
                sleep: DisplayProfile(kelvin: 1900, brightness: 72, dimOpacity: 26)
            )
        case .reading:
            PresetProfiles(
                day: DisplayProfile(kelvin: 4000, brightness: 100, dimOpacity: 0),
                night: DisplayProfile(kelvin: 3300, brightness: 92, dimOpacity: 5),
                sleep: DisplayProfile(kelvin: 2700, brightness: 82, dimOpacity: 14)
            )
        case .lateNight:
            PresetProfiles(
                day: DisplayProfile(kelvin: 3200, brightness: 95, dimOpacity: 4),
                night: DisplayProfile(kelvin: 2300, brightness: 78, dimOpacity: 18),
                sleep: DisplayProfile(kelvin: 1700, brightness: 60, dimOpacity: 36)
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
