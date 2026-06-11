import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var displayController: DisplayController
    @State private var selectedPhase: ActivePhase = .day
    @State private var now = Date()

    private let editablePhases: [ActivePhase] = [.day, .night, .sleep]
    private let presetOptions = LumaPreset.allCases
    private let quickPresetOptions: [LumaPreset] = [.clear, .barely, .subtle, .balanced, .high, .deep]

    var body: some View {
        VStack(spacing: 0) {
            header

            DayArcView(schedule: preferences.settings.schedule, now: now)
                .frame(height: 78)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            pauseRow
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            Hairline()

            presetControls
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Hairline()

            phaseEditor
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            footer
        }
        .frame(width: 316)
        .background(LumaPalette.popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LumaPalette.border, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        .environment(\.colorScheme, .dark)
        .tint(LumaPalette.accent)
        .onAppear {
            selectedPhase = normalized(displayController.runtime.activePhase)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                LumaMark(size: 20, color: LumaPalette.accent)

                Text(displayController.runtime.isPaused ? "Paused" : displayController.runtime.activePhase.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LumaPalette.primaryText)

                Spacer(minLength: 8)

                presetMenu
            }

            Text(statusDetail)
                .font(.system(size: 11))
                .foregroundStyle(LumaPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var presetMenu: some View {
        Menu {
            ForEach(presetOptions) { preset in
                Button(preset.title) {
                    preferences.applyPreset(preset)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(LumaPalette.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: LumaPalette.accent.opacity(0.65), radius: 4)

                Text(preferences.settings.selectedPreset.title)
                    .font(.system(size: 11))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(LumaPalette.secondaryText)
            }
            .foregroundStyle(LumaPalette.primaryText)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(LumaPalette.controlFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(LumaPalette.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 124)
    }

    private var statusDetail: String {
        if displayController.runtime.isPaused {
            return "Display reset to normal"
        }

        let profile = displayController.runtime.lastAppliedProfile
        let fallback = displayController.runtime.usedOverlayFallback ? " · Overlay" : ""
        return "\(profile.kelvinText) · \(profile.brightnessText) · \(nextTransitionText)\(fallback)"
    }

    private var nextTransitionText: String {
        guard let transition = nextPhaseChange(after: now) else {
            return preferences.settings.schedule.mode == .sun ? "sun schedule" : "manual schedule"
        }

        return "until \(transition.shortTimeString)"
    }

    private var pauseRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LumaPalette.secondaryText)
                .frame(width: 14)

            Text("Pause")
                .font(.system(size: 12))
                .foregroundStyle(LumaPalette.primaryText)

            Spacer()

            Toggle("", isOn: pauseBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(LumaPalette.controlFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(LumaPalette.subtleBorder, lineWidth: 0.5)
        }
    }

    private var presetControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strength")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(LumaPalette.captionText)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(Array(quickPresetOptions.prefix(4))) { preset in
                        PresetChip(
                            title: preset.title,
                            isSelected: preferences.settings.selectedPreset == preset
                        ) {
                            preferences.applyPreset(preset)
                        }
                    }
                }

                HStack(spacing: 5) {
                    ForEach(Array(quickPresetOptions.suffix(2))) { preset in
                        PresetChip(
                            title: preset.title,
                            isSelected: preferences.settings.selectedPreset == preset
                        ) {
                            preferences.applyPreset(preset)
                        }
                    }
                }
            }
        }
    }

    private var phaseEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhaseSegmentedControl(selection: $selectedPhase, phases: editablePhases)

            ProfileSliderRow(
                title: "Warmth",
                value: profileValue(profileBinding(for: selectedPhase), \.kelvin),
                range: 1000...10000,
                step: 100,
                format: { "\(Int($0))K" }
            )

            ProfileSliderRow(
                title: "Brightness",
                value: profileValue(profileBinding(for: selectedPhase), \.brightness),
                range: 5...150,
                step: 1,
                format: { "\(Int($0))%" }
            )

            ProfileSliderRow(
                title: "Dim",
                value: profileValue(profileBinding(for: selectedPhase), \.dimOpacity),
                range: 0...85,
                step: 1,
                format: { "\(Int($0))%" }
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            FooterIconButton(systemName: "gearshape", help: "Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            FooterIconButton(systemName: "arrow.counterclockwise", help: "Reset display") {
                displayController.setPaused(true)
                displayController.resetDisplay()
            }

            Spacer()

            FooterIconButton(systemName: "power", help: "Quit") {
                displayController.resetDisplay()
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(LumaPalette.footerFill)
        .overlay(alignment: .top) {
            Hairline()
        }
    }

    private var pauseBinding: Binding<Bool> {
        Binding(
            get: { displayController.runtime.isPaused },
            set: { displayController.setPaused($0) }
        )
    }

    private func profileBinding(for phase: ActivePhase) -> Binding<DisplayProfile> {
        Binding(
            get: {
                switch phase {
                case .day:
                    preferences.settings.day
                case .night:
                    preferences.settings.night
                case .sleep:
                    preferences.settings.sleep
                case .paused:
                    preferences.settings.day
                }
            },
            set: { profile in
                switch phase {
                case .day:
                    preferences.settings.day = profile
                case .night:
                    preferences.settings.night = profile
                case .sleep:
                    preferences.settings.sleep = profile
                case .paused:
                    preferences.settings.day = profile
                }
            }
        )
    }

    private func profileValue(
        _ profile: Binding<DisplayProfile>,
        _ keyPath: WritableKeyPath<DisplayProfile, Double>
    ) -> Binding<Double> {
        Binding(
            get: { profile.wrappedValue[keyPath: keyPath] },
            set: {
                profile.wrappedValue[keyPath: keyPath] = $0
                preferences.markCustomPreset()
            }
        )
    }

    private func nextPhaseChange(after date: Date) -> Date? {
        let schedule = preferences.settings.schedule
        let calendar = Calendar.current
        let currentPhase = schedule.phase(at: date, calendar: calendar)
        let roundedDate = calendar.date(bySetting: .second, value: 0, of: date) ?? date

        for minute in 1...1_440 {
            guard let candidate = calendar.date(byAdding: .minute, value: minute, to: roundedDate) else {
                continue
            }

            if schedule.phase(at: candidate, calendar: calendar) != currentPhase {
                return candidate
            }
        }

        return nil
    }

    private func normalized(_ phase: ActivePhase) -> ActivePhase {
        editablePhases.contains(phase) ? phase : .day
    }
}

private struct DayArcView: View {
    let schedule: ScheduleSettings
    let now: Date

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LumaPalette.arcBase)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.42), location: 0),
                        .init(color: .clear, location: 0.32),
                        .init(color: .clear, location: 0.72),
                        .init(color: .black.opacity(0.24), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.52), location: 0),
                        .init(color: LumaPalette.dayBand.opacity(0.12), location: 0.30),
                        .init(color: LumaPalette.dayBand.opacity(0.14), location: 0.62),
                        .init(color: LumaPalette.nightBand.opacity(0.30), location: 0.86),
                        .init(color: .black.opacity(0.48), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                ForEach(timelineSegments) { segment in
                    segment.phase.timelineColor
                        .frame(width: max(1, proxy.size.width * segment.widthFraction), height: 8)
                        .offset(x: proxy.size.width * segment.startFraction)
                        .opacity(0.9)
                }

                tickLabels(in: proxy.size)
                transitionIcons(in: proxy.size)
                nowMarker(in: proxy.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(LumaPalette.subtleBorder, lineWidth: 0.5)
            }
        }
    }

    private var timelineSegments: [TimelineSegment] {
        let startOfDay = calendar.startOfDay(for: now)
        let boundaries = timelineBoundaries(startOfDay: startOfDay)
        var segments: [TimelineSegment] = []

        for index in 0..<(boundaries.count - 1) {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            guard end > start else {
                continue
            }

            let midpoint = start + ((end - start) / 2)
            let midpointDate = calendar.date(byAdding: .minute, value: midpoint, to: startOfDay) ?? startOfDay
            let phase = schedule.phase(at: midpointDate, calendar: calendar)
            segments.append(TimelineSegment(startMinute: start, endMinute: end, phase: phase))
        }

        return segments
    }

    private func timelineBoundaries(startOfDay: Date) -> [Int] {
        var boundaries = Set([0, 1_440])

        if schedule.sleepEnabled {
            boundaries.insert(schedule.bedtime.minutesSinceMidnight)
            boundaries.insert(schedule.wakeTime.minutesSinceMidnight)
        }

        if schedule.mode == .sun,
           let events = schedule.sunEvents(on: startOfDay, calendar: calendar) {
            boundaries.insert(minuteOfDay(for: events.sunrise))
            boundaries.insert(minuteOfDay(for: events.sunset))
        } else {
            boundaries.insert(schedule.nightStart.minutesSinceMidnight)
            boundaries.insert(schedule.nightEnd.minutesSinceMidnight)
        }

        return boundaries
            .filter { (0...1_440).contains($0) }
            .sorted()
    }

    private func tickLabels(in size: CGSize) -> some View {
        ForEach(TimelineTick.defaults) { tick in
            Text(tick.label)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(LumaPalette.arcLabel)
                .position(x: size.width * tick.fraction, y: 14)
        }
    }

    private func transitionIcons(in size: CGSize) -> some View {
        let points = transitionFractions

        return ZStack {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LumaPalette.dayBand.opacity(0.92))
                .position(x: size.width * points.sunrise, y: 40)

            Image(systemName: "moon.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LumaPalette.nightBand.opacity(0.92))
                .position(x: size.width * points.sunset, y: 40)
        }
    }

    private func nowMarker(in size: CGSize) -> some View {
        let x = size.width * currentFraction

        return ZStack {
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 1)
                .position(x: x, y: size.height / 2)

            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
                .shadow(color: LumaPalette.dayBand.opacity(0.75), radius: 8)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 6)
                }
                .position(x: x, y: 56)
        }
    }

    private var transitionFractions: (sunrise: Double, sunset: Double) {
        if schedule.mode == .sun,
           let events = schedule.sunEvents(on: now, calendar: calendar) {
            return (
                Double(minuteOfDay(for: events.sunrise)) / 1_440,
                Double(minuteOfDay(for: events.sunset)) / 1_440
            )
        }

        return (
            Double(schedule.nightEnd.minutesSinceMidnight) / 1_440,
            Double(schedule.nightStart.minutesSinceMidnight) / 1_440
        )
    }

    private var currentFraction: Double {
        Double(minuteOfDay(for: now)) / 1_440
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return min(max((components.hour ?? 0) * 60 + (components.minute ?? 0), 0), 1_440)
    }
}

private struct TimelineSegment: Identifiable {
    let startMinute: Int
    let endMinute: Int
    let phase: ActivePhase

    var id: String {
        "\(startMinute)-\(endMinute)-\(phase.rawValue)"
    }

    var startFraction: Double {
        Double(startMinute) / 1_440
    }

    var widthFraction: Double {
        Double(endMinute - startMinute) / 1_440
    }
}

private struct TimelineTick: Identifiable {
    let minute: Int
    let label: String

    var id: Int {
        minute
    }

    var fraction: Double {
        Double(minute) / 1_440
    }

    static let defaults = [
        TimelineTick(minute: 4 * 60, label: "4a"),
        TimelineTick(minute: 6 * 60, label: "6a"),
        TimelineTick(minute: 12 * 60, label: "12p"),
        TimelineTick(minute: 18 * 60, label: "6p"),
        TimelineTick(minute: 21 * 60, label: "9p")
    ]
}

private struct ProfileSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(LumaPalette.primaryText)
                .frame(width: 72, alignment: .leading)

            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
                .tint(LumaPalette.accent)

            Text(format(value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LumaPalette.secondaryText)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: 22)
    }
}

private struct PhaseSegmentedControl: View {
    @Binding var selection: ActivePhase
    let phases: [ActivePhase]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(phases, id: \.self) { phase in
                Button {
                    selection = phase
                } label: {
                    Text(phase.title)
                        .font(.system(size: 11.5, weight: selection == phase ? .semibold : .regular))
                        .foregroundStyle(selection == phase ? LumaPalette.primaryText : LumaPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            selection == phase ? LumaPalette.segmentSelectedFill : .clear,
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )
                        .overlay {
                            if selection == phase {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(.white.opacity(0.055), lineWidth: 0.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(LumaPalette.segmentFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct PresetChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isSelected ? LumaPalette.accent : LumaPalette.secondaryText)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(isSelected ? LumaPalette.accent.opacity(0.18) : LumaPalette.chipFill, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? LumaPalette.accent.opacity(0.35) : .clear, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct FooterIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LumaPalette.secondaryText)
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .background(.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 0.5)
    }
}

private struct LumaMark: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 1)
                .frame(width: size, height: size)
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 1.1)
                .frame(width: size * 0.7, height: size * 0.7)
            Circle()
                .fill(color)
                .frame(width: size * 0.36, height: size * 0.36)
        }
        .frame(width: size, height: size)
    }
}

private enum LumaPalette {
    static let accent = Color(red: 0.94, green: 0.62, blue: 0.25)
    static let popoverBackground = Color(red: 0.12, green: 0.10, blue: 0.09).opacity(0.96)
    static let footerFill = Color.black.opacity(0.18)
    static let controlFill = Color.white.opacity(0.045)
    static let chipFill = Color.white.opacity(0.04)
    static let segmentFill = Color.black.opacity(0.25)
    static let segmentSelectedFill = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.08)
    static let subtleBorder = Color.white.opacity(0.055)
    static let primaryText = Color(red: 0.96, green: 0.94, blue: 0.91)
    static let secondaryText = primaryText.opacity(0.58)
    static let captionText = primaryText.opacity(0.42)
    static let arcLabel = primaryText.opacity(0.45)
    static let arcBase = LinearGradient(
        colors: [
            Color.white.opacity(0.035),
            Color.black.opacity(0.15)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let dayBand = Color(red: 0.96, green: 0.74, blue: 0.42)
    static let nightBand = Color(red: 0.86, green: 0.39, blue: 0.18)
    static let sleepBand = Color(red: 0.54, green: 0.20, blue: 0.13)
}

private extension ActivePhase {
    var timelineColor: Color {
        switch self {
        case .day:
            LumaPalette.dayBand
        case .night:
            LumaPalette.nightBand
        case .sleep:
            LumaPalette.sleepBand
        case .paused:
            LumaPalette.secondaryText
        }
    }
}

private extension DisplayProfile {
    var kelvinText: String {
        "\(Int(kelvin))K"
    }

    var brightnessText: String {
        "\(Int(brightness))%"
    }
}

private extension Date {
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
