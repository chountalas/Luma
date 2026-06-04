import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var displayController: DisplayController
    @State private var importStatus: String?

    var body: some View {
        TabView {
            profilesTab
                .tabItem {
                    Label("Profiles", systemImage: "slider.horizontal.3")
                }

            scheduleTab
                .tabItem {
                    Label("Schedule", systemImage: "clock")
                }

            systemTab
                .tabItem {
                    Label("System", systemImage: "gearshape")
                }
        }
        .padding()
    }

    private var profilesTab: some View {
        Form {
            presetsSection
            profileSection("Day", profile: $preferences.settings.day)
            profileSection("Night", profile: $preferences.settings.night)
            profileSection("Sleep", profile: $preferences.settings.sleep)
        }
        .formStyle(.grouped)
    }

    private var scheduleTab: some View {
        Form {
            Section("Mode") {
                Picker("Night schedule", selection: $preferences.settings.schedule.mode) {
                    ForEach(ScheduleMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if preferences.settings.schedule.mode == .sun {
                    LabeledContent("Night window", value: sunScheduleSummary)
                    coordinateField("Latitude", value: $preferences.settings.schedule.latitude)
                    coordinateField("Longitude", value: $preferences.settings.schedule.longitude)
                }
            }

            Section(preferences.settings.schedule.mode == .sun ? "Manual fallback" : "Night") {
                timePicker("Starts", time: $preferences.settings.schedule.nightStart)
                timePicker("Ends", time: $preferences.settings.schedule.nightEnd)
            }

            Section("Sleep") {
                Toggle("Enable sleep profile", isOn: $preferences.settings.schedule.sleepEnabled)
                timePicker("Bedtime", time: $preferences.settings.schedule.bedtime)
                timePicker("Wake", time: $preferences.settings.schedule.wakeTime)
            }

            Section("Transitions") {
                if preferences.settings.schedule.usesSolarCurve() {
                    LabeledContent("Day/night", value: "Solar curve")
                } else {
                    durationField(
                        "Day/night",
                        value: $preferences.settings.schedule.dayNightTransitionSeconds,
                        range: 0...28_800
                    )
                }
                durationField(
                    "Sleep",
                    value: $preferences.settings.schedule.sleepTransitionSeconds,
                    range: 0...14_400
                )
                numericField("Pause seconds", value: $preferences.settings.schedule.pauseTransitionSeconds)
            }
        }
        .formStyle(.grouped)
    }

    private var systemTab: some View {
        Form {
            Section("Behavior") {
                Toggle("Start at login", isOn: $preferences.settings.launchAtLogin)
                Toggle("Use overlay fallback", isOn: $preferences.settings.useOverlayFallback)
                Toggle("Global hotkeys", isOn: $preferences.settings.hotkeys.enabled)
            }

            Section("Status") {
                LabeledContent("Active phase", value: displayController.runtime.activePhase.title)
                LabeledContent("Displays", value: "\(displayController.runtime.displayCount)")
                LabeledContent("Fallback", value: displayController.runtime.usedOverlayFallback ? "Overlay" : "Gamma")
                if let error = displayController.runtime.lastError {
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Import") {
                Button("Import Iris Visual Settings") {
                    importStatus = preferences.importSafeIrisPreferences()
                        ? "Imported visual and schedule settings."
                        : "No Iris preferences plist was found."
                }
                if let importStatus {
                    Text(importStatus)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Reset") {
                Button("Restore Luma Defaults") {
                    preferences.resetToDefaults()
                }
                Button("Reset Display Now") {
                    displayController.setPaused(true)
                    displayController.resetDisplay()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var presetsSection: some View {
        Section("Presets") {
            Picker("Strength", selection: Binding(
                get: { preferences.settings.selectedPreset },
                set: { preferences.applyPreset($0) }
            )) {
                ForEach(LumaPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Text(preferences.settings.selectedPreset.detail)
                .foregroundStyle(.secondary)
        }
    }

    private func profileSection(_ title: String, profile: Binding<DisplayProfile>) -> some View {
        Section(title) {
            SliderRow(title: "Temperature", value: profileValue(profile, \.kelvin), range: 1000...10000, step: 100, suffix: "K")
            SliderRow(title: "Brightness", value: profileValue(profile, \.brightness), range: 5...150, step: 1, suffix: "%")
            SliderRow(title: "Dim opacity", value: profileValue(profile, \.dimOpacity), range: 0...85, step: 1, suffix: "%")
        }
    }

    private func profileValue(_ profile: Binding<DisplayProfile>, _ keyPath: WritableKeyPath<DisplayProfile, Double>) -> Binding<Double> {
        Binding(
            get: { profile.wrappedValue[keyPath: keyPath] },
            set: {
                profile.wrappedValue[keyPath: keyPath] = $0
                preferences.markCustomPreset()
            }
        )
    }

    private func timePicker(_ title: String, time: Binding<TimeOfDay>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker("Hour", selection: Binding(
                get: { time.wrappedValue.hour },
                set: { time.wrappedValue.hour = $0 }
            )) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .frame(width: 80)
            Picker("Minute", selection: Binding(
                get: { time.wrappedValue.minute },
                set: { time.wrappedValue.minute = $0 }
            )) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .frame(width: 80)
        }
    }

    private func numericField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    private func durationField(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: value, in: range, step: 900) {
                Text(durationText(value.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 72, alignment: .trailing)
            }
            .frame(width: 128)
        }
    }

    private func durationText(_ seconds: Double) -> String {
        let minutes = Int((max(seconds, 0) / 60).rounded())
        if minutes < 1 {
            return "\(Int(max(seconds, 0)))s"
        }

        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    private func coordinateField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(4)))
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }

    private var sunScheduleSummary: String {
        let schedule = preferences.settings.schedule
        guard schedule.hasValidSunCoordinates else {
            return "Invalid coordinates; using manual fallback"
        }

        guard let events = schedule.sunEvents(on: Date()) else {
            return "No sun event today; using manual fallback"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: events.sunset)) to \(formatter.string(from: events.sunrise))"
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 110, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text("\(Int(value))\(suffix)")
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
        }
    }
}
