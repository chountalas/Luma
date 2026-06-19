import Foundation

enum SunCalculator {
    struct SunEvents: Equatable {
        var sunrise: Date
        var sunset: Date
    }

    static func events(on date: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> SunEvents? {
        guard latitude.isFinite,
              longitude.isFinite,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

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

        let daylightOffsetProbe = dayStart.addingTimeInterval(12 * 3600)
        let offsetHours = Double(calendar.timeZone.secondsFromGMT(for: daylightOffsetProbe)) / 3600
        return SunEvents(
            sunrise: dayStart.addingTimeInterval(normalizedHours(sunriseHours + offsetHours) * 3600),
            sunset: dayStart.addingTimeInterval(normalizedHours(sunsetHours + offsetHours) * 3600)
        )
    }

    /// Solar elevation in degrees above the horizon, via the NOAA solar-position
    /// equations. Drives the smooth daytime-to-night blend through twilight.
    static func solarElevation(on date: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> Double? {
        guard latitude.isFinite,
              longitude.isFinite,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

        let dayStart = calendar.startOfDay(for: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: dayStart) ?? 1
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let nanosecond = Double(components.nanosecond ?? 0)
        let localMinutes = (hour * 60) + minute + (second / 60) + (nanosecond / 60_000_000_000)
        let fractionalHour = localMinutes / 60
        let fractionalYear = (2 * Double.pi / 365) * (Double(dayOfYear) - 1 + ((fractionalHour - 12) / 24))

        let equationOfTime = 229.18 * (
            0.000075
                + 0.001868 * cos(fractionalYear)
                - 0.032077 * sin(fractionalYear)
                - 0.014615 * cos(2 * fractionalYear)
                - 0.040849 * sin(2 * fractionalYear)
        )
        let declination = 0.006918
            - 0.399912 * cos(fractionalYear)
            + 0.070257 * sin(fractionalYear)
            - 0.006758 * cos(2 * fractionalYear)
            + 0.000907 * sin(2 * fractionalYear)
            - 0.002697 * cos(3 * fractionalYear)
            + 0.00148 * sin(3 * fractionalYear)
        let timezoneOffsetHours = Double(calendar.timeZone.secondsFromGMT(for: date)) / 3600
        let timeOffset = equationOfTime + (4 * longitude) - (60 * timezoneOffsetHours)
        let trueSolarMinutes = normalizedMinutes(localMinutes + timeOffset)
        var hourAngle = (trueSolarMinutes / 4) - 180
        if hourAngle < -180 {
            hourAngle += 360
        }

        let latitudeRadians = degreesToRadians(latitude)
        let hourAngleRadians = degreesToRadians(hourAngle)
        let cosZenith = sin(latitudeRadians) * sin(declination)
            + cos(latitudeRadians) * cos(declination) * cos(hourAngleRadians)
        let zenith = acos(min(max(cosZenith, -1), 1))
        return 90 - radiansToDegrees(zenith)
    }

    /// Sunrise/sunset via the standard US Naval Observatory almanac algorithm.
    /// Zenith 90.833 degrees folds in atmospheric refraction and the sun's disc
    /// radius; returns nil during polar day/night when the sun never crosses it.
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

    private static func normalizedMinutes(_ minutes: Double) -> Double {
        let value = minutes.truncatingRemainder(dividingBy: 1_440)
        return value < 0 ? value + 1_440 : value
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
