import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var displayController: DisplayController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            Toggle("Paused", isOn: pauseBinding)
                .toggleStyle(.switch)

            presetControls

            phaseControls(title: "Day", profile: $preferences.settings.day)
            phaseControls(title: "Night", profile: $preferences.settings.night)
            phaseControls(title: "Sleep", profile: $preferences.settings.sleep)

            Divider()

            HStack {
                Button("Settings") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Reset Display") {
                    displayController.setPaused(true)
                    displayController.resetDisplay()
                }
                Button("Quit") {
                    displayController.resetDisplay()
                    NSApp.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 360)
        .tint(.green)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.16, green: 0.62, blue: 0.34), Color(red: 0.08, green: 0.38, blue: 0.27)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text("Luma")
                    .font(.headline)
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        if displayController.runtime.isPaused {
            return "Paused"
        }

        let fallback = displayController.runtime.usedOverlayFallback ? " · Overlay" : ""
        return "\(displayController.runtime.activePhase.title) · \(Int(displayController.runtime.lastAppliedProfile.kelvin))K\(fallback)"
    }

    private var pauseBinding: Binding<Bool> {
        Binding(
            get: { displayController.runtime.isPaused },
            set: { displayController.setPaused($0) }
        )
    }

    private var presetControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Preset", selection: Binding(
                get: { preferences.settings.selectedPreset },
                set: { preferences.applyPreset($0) }
            )) {
                ForEach(LumaPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func phaseControls(title: String, profile: Binding<DisplayProfile>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("Warmth")
                    .frame(width: 72, alignment: .leading)
                Slider(value: profileValue(profile, \.kelvin), in: 1000...10000, step: 100)
                Text("\(Int(profile.wrappedValue.kelvin))K")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
            HStack {
                Text("Brightness")
                    .frame(width: 72, alignment: .leading)
                Slider(value: profileValue(profile, \.brightness), in: 5...150, step: 1)
                Text("\(Int(profile.wrappedValue.brightness))%")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
            HStack {
                Text("Dim")
                    .frame(width: 72, alignment: .leading)
                Slider(value: profileValue(profile, \.dimOpacity), in: 0...85, step: 1)
                Text("\(Int(profile.wrappedValue.dimOpacity))%")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
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
}
