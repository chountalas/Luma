import Foundation

struct DisplayProfile: Codable, Equatable {
    var kelvin: Double
    var brightness: Double
    var dimOpacity: Double

    static let dayDefault = DisplayProfile(kelvin: 3600, brightness: 100, dimOpacity: 0)
    static let nightDefault = DisplayProfile(kelvin: 2500, brightness: 90, dimOpacity: 9)
    static let sleepDefault = DisplayProfile(kelvin: 2000, brightness: 78, dimOpacity: 18)

    var normalizedBrightness: Double {
        min(max(brightness / 100, 0.05), 1.5)
    }

    var normalizedDimOpacity: Double {
        min(max(dimOpacity / 100, 0), 0.85)
    }
}
