import Foundation

enum LumaPreset: String, Codable, CaseIterable, Identifiable {
    case subtle
    case balanced
    case deep
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subtle: "Subtle"
        case .balanced: "Balanced"
        case .deep: "Deep"
        case .custom: "Custom"
        }
    }

    var detail: String {
        switch self {
        case .subtle: "Lighter warmth and dimming"
        case .balanced: "Daily default"
        case .deep: "Stronger night protection"
        case .custom: "Manual profile settings"
        }
    }

    var profiles: PresetProfiles? {
        switch self {
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
        case .deep:
            PresetProfiles(
                day: DisplayProfile(kelvin: 2500, brightness: 96, dimOpacity: 4),
                night: DisplayProfile(kelvin: 1500, brightness: 78, dimOpacity: 18),
                sleep: DisplayProfile(kelvin: 1200, brightness: 62, dimOpacity: 32)
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
