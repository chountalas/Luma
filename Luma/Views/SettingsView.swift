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
                    LabeledContent("Night window", value: "Sunset to sunrise")
                    coordinateField("Latitude", value: $preferences.settings.schedule.latitude)
                    coordinateField("Longitude", value: $preferences.settings.schedule.longitude)
                }
            }

            Section("Night") {
                timePicker("Starts", time: $preferences.settings.schedule.nightStart)
                timePicker("Ends", time: $preferences.settings.schedule.nightEnd)
            }

            Section("Sleep") {
                Toggle("Enable sleep profile", isOn: $preferences.settings.schedule.sleepEnabled)
                timePicker("Bedtime", time: $preferences.settings.schedule.bedtime)
                timePicker("Wake", time: $preferences.settings.schedule.wakeTime)
            }

            Section("Transitions") {
                numericField("Day/night seconds", value: $preferences.settings.schedule.dayNightTransitionSeconds)
                numericField("Sleep seconds", value: $preferences.settings.schedule.sleepTransitionSeconds)
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

    private func profileSection(_ title: String, profile: Binding<DisplayProfile>) -> some View {
        Section(title) {
            SliderRow(title: "Temperature", value: profile.kelvin, range: 1000...10000, step: 100, suffix: "K")
            SliderRow(title: "Brightness", value: profile.brightness, range: 5...150, step: 1, suffix: "%")
            SliderRow(title: "Dim opacity", value: profile.dimOpacity, range: 0...85, step: 1, suffix: "%")
        }
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

    private func coordinateField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(4)))
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
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
