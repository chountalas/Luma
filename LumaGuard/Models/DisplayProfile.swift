import Foundation

struct DisplayProfile: Codable, Equatable {
    var kelvin: Double
    var brightness: Double
    var dimOpacity: Double

    static let dayDefault = DisplayProfile(kelvin: 2800, brightness: 100, dimOpacity: 0)
    static let nightDefault = DisplayProfile(kelvin: 1900, brightness: 85, dimOpacity: 10)
    static let sleepDefault = DisplayProfile(kelvin: 3700, brightness: 80, dimOpacity: 20)

    var normalizedBrightness: Double {
        min(max(brightness / 100, 0.05), 1.5)
    }

    var normalizedDimOpacity: Double {
        min(max(dimOpacity / 100, 0), 0.85)
    }
}

