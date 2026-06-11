import Foundation

struct DisplayProfile: Codable, Equatable {
    var kelvin: Double
    var brightness: Double
    var dimOpacity: Double

    /// Approximates an untouched display; used as the visual endpoint when pausing.
    static let neutral = DisplayProfile(kelvin: 6500, brightness: 100, dimOpacity: 0)
    static let dayDefault = DisplayProfile(kelvin: 4300, brightness: 100, dimOpacity: 0)
    static let nightDefault = DisplayProfile(kelvin: 3700, brightness: 96, dimOpacity: 3)
    static let sleepDefault = DisplayProfile(kelvin: 3100, brightness: 90, dimOpacity: 10)

    var normalizedBrightness: Double {
        min(max(brightness / 100, 0.05), 1.5)
    }

    var normalizedDimOpacity: Double {
        min(max(dimOpacity / 100, 0), 0.85)
    }

    static func interpolated(from start: DisplayProfile, to target: DisplayProfile, progress: Double) -> DisplayProfile {
        let progress = min(max(progress, 0), 1)
        return DisplayProfile(
            kelvin: start.kelvin + (target.kelvin - start.kelvin) * progress,
            brightness: start.brightness + (target.brightness - start.brightness) * progress,
            dimOpacity: start.dimOpacity + (target.dimOpacity - start.dimOpacity) * progress
        )
    }
}
