import Foundation

enum ActivePhase: String, Codable, CaseIterable {
    case day
    case night
    case sleep
    case paused

    var title: String {
        switch self {
        case .day: "Day"
        case .night: "Night"
        case .sleep: "Sleep"
        case .paused: "Paused"
        }
    }
}

enum ScheduleMode: String, Codable, CaseIterable, Identifiable {
    case sun
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sun: "Sunset to sunrise"
        case .manual: "Manual hours"
        }
    }
}

struct TimeOfDay: Codable, Equatable, Comparable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

struct PhaseTransition: Equatable {
    var from: ActivePhase
    var to: ActivePhase
    var progress: Double
}

struct ScheduleSettings: Codable, Equatable {
    static let defaultDayNightTransitionSeconds: Double = 14_400
    static let defaultSleepTransitionSeconds: Double = 7_200
    static let defaultPauseTransitionSeconds: Double = 1
    static let fullNightSolarElevationDegrees: Double = -8
    static let fullDaySolarElevationDegrees: Double = 35

    var mode: ScheduleMode = .manual
    var nightStart = TimeOfDay(hour: 20, minute: 0)
    var nightEnd = TimeOfDay(hour: 6, minute: 0)
    var latitude: Double = 200
    var longitude: Double = 0
    var sleepEnabled = true
    var bedtime = TimeOfDay(hour: 0, minute: 0)
    var wakeTime = TimeOfDay(hour: 4, minute: 0)
    var dayNightTransitionSeconds: Double = Self.defaultDayNightTransitionSeconds
    var sleepTransitionSeconds: Double = Self.defaultSleepTransitionSeconds
    var pauseTransitionSeconds: Double = Self.defaultPauseTransitionSeconds

    var hasValidSunCoordinates: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    func phase(at date: Date, calendar: Calendar = .current) -> ActivePhase {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let current = TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)

        if sleepEnabled && contains(current, start: bedtime, end: wakeTime) {
            return .sleep
        }

        if mode == .sun,
           let events = sunEvents(on: date, calendar: calendar) {
            return date >= events.sunset || date < events.sunrise ? .night : .day
        }

        if contains(current, start: nightStart, end: nightEnd) {
            return .night
        }

        return .day
    }

    func sunEvents(on date: Date, calendar: Calendar = .current) -> SunCalculator.SunEvents? {
        guard hasValidSunCoordinates else {
            return nil
        }

        return SunCalculator.events(on: date, latitude: latitude, longitude: longitude, calendar: calendar)
    }

    func usesSolarCurve(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        mode == .sun && sunEvents(on: date, calendar: calendar) != nil
    }

    func solarNightProgress(at date: Date, calendar: Calendar = .current) -> Double? {
        guard usesSolarCurve(at: date, calendar: calendar),
              let elevation = SunCalculator.solarElevation(
                on: date,
                latitude: latitude,
                longitude: longitude,
                calendar: calendar
              ) else {
            return nil
        }

        let daylightProgress = smoothstep(
            edge0: Self.fullNightSolarElevationDegrees,
            edge1: Self.fullDaySolarElevationDegrees,
            value: elevation
        )
        return 1 - daylightProgress
    }

    func phaseTransition(at date: Date, calendar: Calendar = .current) -> PhaseTransition? {
        let boundaries = phaseChangeBoundaries(around: date, calendar: calendar)
        var nearest: (boundary: PhaseBoundary, distance: TimeInterval, progress: Double)?

        for boundary in boundaries {
            let duration = transitionSeconds(from: boundary.from, to: boundary.to)
            guard duration > 0 else {
                continue
            }

            let offset = date.timeIntervalSince(boundary.date)
            let halfDuration = duration / 2
            guard abs(offset) <= halfDuration else {
                continue
            }

            let progress = (offset + halfDuration) / duration
            let distance = abs(offset)
            if nearest == nil || distance < nearest!.distance {
                nearest = (boundary, distance, progress)
            }
        }

        guard let nearest else {
            return nil
        }

        return PhaseTransition(
            from: nearest.boundary.from,
            to: nearest.boundary.to,
            progress: min(max(nearest.progress, 0), 1)
        )
    }

    private func phaseChangeBoundaries(around date: Date, calendar: Calendar) -> [PhaseBoundary] {
        uniqueDates(phaseChangeCandidates(around: date, calendar: calendar)).compactMap { candidate in
            let from = phase(at: candidate.addingTimeInterval(-1), calendar: calendar)
            let to = phase(at: candidate.addingTimeInterval(1), calendar: calendar)
            guard from != to else {
                return nil
            }

            return PhaseBoundary(date: candidate, from: from, to: to)
        }
    }

    private func phaseChangeCandidates(around date: Date, calendar: Calendar) -> [Date] {
        let startOfDay = calendar.startOfDay(for: date)
        var candidates: [Date] = []

        for dayOffset in -2...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else {
                continue
            }

            if sleepEnabled {
                candidates.append(contentsOf: [
                    dateOn(day, time: bedtime, calendar: calendar),
                    dateOn(day, time: wakeTime, calendar: calendar)
                ].compactMap { $0 })
            }

            if mode == .sun, let events = sunEvents(on: day, calendar: calendar) {
                candidates.append(events.sunrise)
                candidates.append(events.sunset)
            } else {
                candidates.append(contentsOf: [
                    dateOn(day, time: nightStart, calendar: calendar),
                    dateOn(day, time: nightEnd, calendar: calendar)
                ].compactMap { $0 })
            }
        }

        return candidates
    }

    private func uniqueDates(_ dates: [Date]) -> [Date] {
        dates.sorted().reduce(into: [Date]()) { unique, date in
            if let last = unique.last, abs(date.timeIntervalSince(last)) < 0.5 {
                return
            }

            unique.append(date)
        }
    }

    private func dateOn(_ day: Date, time: TimeOfDay, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components)
    }

    private func transitionSeconds(from: ActivePhase, to: ActivePhase) -> Double {
        let seconds = from == .sleep || to == .sleep
            ? sleepTransitionSeconds
            : dayNightTransitionSeconds
        return max(seconds, 0)
    }

    private func smoothstep(edge0: Double, edge1: Double, value: Double) -> Double {
        guard edge0 != edge1 else {
            return value < edge0 ? 0 : 1
        }

        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - (2 * progress))
    }

    private func contains(_ time: TimeOfDay, start: TimeOfDay, end: TimeOfDay) -> Bool {
        if start == end {
            return false
        }

        if start < end {
            return time >= start && time < end
        }

        return time >= start || time < end
    }
}

private struct PhaseBoundary {
    var date: Date
    var from: ActivePhase
    var to: ActivePhase
}
