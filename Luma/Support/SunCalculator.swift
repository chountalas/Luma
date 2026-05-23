import Foundation

enum SunCalculator {
    struct SunEvents: Equatable {
        var sunrise: Date
        var sunset: Date
    }

    static func events(on date: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> SunEvents? {
        let dayStart = calendar.startOfDay(for: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: dayStart) ?? 1
        let longitudeHour = longitude / 15

        guard let sunriseHours = eventHours(
            dayOfYear: dayOfYear,
            latitude: latitude,
            longitudeHour: longitudeHour,
            isSunrise: true
        ),
        let sunsetHours = eventHours(
            dayOfYear: dayOfYear,
            latitude: latitude,
            longitudeHour: longitudeHour,
            isSunrise: false
        ) else {
            return nil
        }

        let offsetHours = Double(calendar.timeZone.secondsFromGMT(for: dayStart)) / 3600
        return SunEvents(
            sunrise: dayStart.addingTimeInterval(normalizedHours(sunriseHours + offsetHours) * 3600),
            sunset: dayStart.addingTimeInterval(normalizedHours(sunsetHours + offsetHours) * 3600)
        )
    }

    private static func eventHours(dayOfYear: Int, latitude: Double, longitudeHour: Double, isSunrise: Bool) -> Double? {
        let zenith = 90.833
        let t = Double(dayOfYear) + ((isSunrise ? 6 : 18) - longitudeHour) / 24
        let meanAnomaly = (0.9856 * t) - 3.289
        var trueLongitude = meanAnomaly
            + 1.916 * sin(degreesToRadians(meanAnomaly))
            + 0.020 * sin(degreesToRadians(2 * meanAnomaly))
            + 282.634
        trueLongitude = normalizedDegrees(trueLongitude)

        var rightAscension = radiansToDegrees(atan(0.91764 * tan(degreesToRadians(trueLongitude))))
        rightAscension = normalizedDegrees(rightAscension)

        let longitudeQuadrant = floor(trueLongitude / 90) * 90
        let ascensionQuadrant = floor(rightAscension / 90) * 90
        rightAscension = (rightAscension + longitudeQuadrant - ascensionQuadrant) / 15

        let sinDeclination = 0.39782 * sin(degreesToRadians(trueLongitude))
        let cosDeclination = cos(asin(sinDeclination))
        let cosHourAngle = (cos(degreesToRadians(zenith)) - sinDeclination * sin(degreesToRadians(latitude)))
            / (cosDeclination * cos(degreesToRadians(latitude)))

        guard cosHourAngle >= -1, cosHourAngle <= 1 else {
            return nil
        }

        let hourAngle = isSunrise
            ? 360 - radiansToDegrees(acos(cosHourAngle))
            : radiansToDegrees(acos(cosHourAngle))
        let localMeanTime = (hourAngle / 15) + rightAscension - (0.06571 * t) - 6.622
        return normalizedHours(localMeanTime - longitudeHour)
    }

    private static func normalizedDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    private static func normalizedHours(_ hours: Double) -> Double {
        let value = hours.truncatingRemainder(dividingBy: 24)
        return value < 0 ? value + 24 : value
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
