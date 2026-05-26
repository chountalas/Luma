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

struct ScheduleSettings: Codable, Equatable {
    var mode: ScheduleMode = .manual
    var nightStart = TimeOfDay(hour: 20, minute: 0)
    var nightEnd = TimeOfDay(hour: 6, minute: 0)
    var latitude: Double = 200
    var longitude: Double = 0
    var sleepEnabled = true
    var bedtime = TimeOfDay(hour: 0, minute: 0)
    var wakeTime = TimeOfDay(hour: 4, minute: 0)
    var dayNightTransitionSeconds: Double = 3600
    var sleepTransitionSeconds: Double = 3600
    var pauseTransitionSeconds: Double = 1

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
