import CoreGraphics
import Foundation

enum ColorTemperature {
    static func rgbMultipliers(kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        let temperature = min(max(kelvin, 1000), 10000) / 100
        let red: Double
        let green: Double
        let blue: Double

        if temperature <= 66 {
            red = 255
            green = 99.4708025861 * log(temperature) - 161.1195681661
            blue = temperature <= 19 ? 0 : 138.5177312231 * log(temperature - 10) - 305.0447927307
        } else {
            red = 329.698727446 * pow(temperature - 60, -0.1332047592)
            green = 288.1221695283 * pow(temperature - 60, -0.0755148492)
            blue = 255
        }

        return (
            clamp(red / 255),
            clamp(green / 255),
            clamp(blue / 255)
        )
    }

    static func gammaTables(profile: DisplayProfile, samples: Int = 256) -> (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue]) {
        let multipliers = rgbMultipliers(kelvin: profile.kelvin)
        let brightness = profile.normalizedBrightness * (1 - profile.normalizedDimOpacity)
        var red = [CGGammaValue]()
        var green = [CGGammaValue]()
        var blue = [CGGammaValue]()
        red.reserveCapacity(samples)
        green.reserveCapacity(samples)
        blue.reserveCapacity(samples)

        for index in 0..<samples {
            let input = Double(index) / Double(samples - 1)
            red.append(CGGammaValue(clamp(input * multipliers.red * brightness)))
            green.append(CGGammaValue(clamp(input * multipliers.green * brightness)))
            blue.append(CGGammaValue(clamp(input * multipliers.blue * brightness)))
        }

        return (red, green, blue)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

