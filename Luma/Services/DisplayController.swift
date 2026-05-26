import AppKit
import CoreGraphics
import Foundation

@MainActor
final class DisplayController: ObservableObject {
    @Published private(set) var runtime = RuntimeState()

    private let overlayController = OverlayController()
    private var currentSettings = LumaSettings()
    private var timer: Timer?
    private var hasInstalledObservers = false
    private var transitionTask: Task<Void, Never>?

    func start(settings: LumaSettings) {
        currentSettings = settings
        installDisplayObservers()
        scheduleTick()
        applyCurrentPhase(animated: false)
    }

    func update(settings: LumaSettings) {
        currentSettings = settings
        applyCurrentPhase(animated: true)
    }

    func setPaused(_ paused: Bool) {
        runtime.isPaused = paused
        applyCurrentPhase(animated: true)
    }

    func togglePaused() {
        setPaused(!runtime.isPaused)
    }

    func resetDisplay() {
        transitionTask?.cancel()
        CGDisplayRestoreColorSyncSettings()
        overlayController.clear()
        runtime.usedOverlayFallback = false
    }

    func nudgeKelvin(_ delta: Double) {
        var settings = currentSettings
        let phase = currentSettings.schedule.phase(at: Date())
        switch phase {
        case .day:
            settings.day.kelvin = clamped(settings.day.kelvin + delta, 1000, 10000)
        case .night:
            settings.night.kelvin = clamped(settings.night.kelvin + delta, 1000, 10000)
        case .sleep:
            settings.sleep.kelvin = clamped(settings.sleep.kelvin + delta, 1000, 10000)
        case .paused:
            break
        }
        currentSettings = settings
        applyCurrentPhase(animated: true)
    }

    func nudgeBrightness(_ delta: Double) {
        var settings = currentSettings
        let phase = currentSettings.schedule.phase(at: Date())
        switch phase {
        case .day:
            settings.day.brightness = clamped(settings.day.brightness + delta, 5, 150)
        case .night:
            settings.night.brightness = clamped(settings.night.brightness + delta, 5, 150)
        case .sleep:
            settings.sleep.brightness = clamped(settings.sleep.brightness + delta, 5, 150)
        case .paused:
            break
        }
        currentSettings = settings
        applyCurrentPhase(animated: true)
    }

    private func scheduleTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.applyCurrentPhase(animated: true)
            }
        }
    }

    private func applyCurrentPhase(animated: Bool) {
        if runtime.isPaused {
            runtime.activePhase = .paused
            resetDisplay()
            return
        }

        let phase = currentSettings.schedule.phase(at: Date())
        let profile = currentSettings.profile(for: phase)
        runtime.activePhase = phase

        let effectiveProfile = animated
            ? interpolatedProfile(from: runtime.lastAppliedProfile, to: profile, progress: 0.35)
            : profile
        runtime.lastAppliedProfile = effectiveProfile

        let success = applyGamma(profile: effectiveProfile)
        if success {
            overlayController.clear()
            runtime.usedOverlayFallback = false
            runtime.lastError = nil
        } else if currentSettings.useOverlayFallback {
            overlayController.apply(profile: effectiveProfile)
            runtime.usedOverlayFallback = true
            runtime.lastError = "Display rejected direct gamma changes; using overlay fallback."
        } else {
            runtime.lastError = "Display rejected direct gamma changes and overlay fallback is disabled."
        }

        if animated && effectiveProfile != profile {
            scheduleTransition(to: profile)
        }
    }

    private func applyGamma(profile: DisplayProfile) -> Bool {
        var displayCount: UInt32 = 0
        var result = CGGetOnlineDisplayList(0, nil, &displayCount)
        guard result == .success, displayCount > 0 else {
            runtime.displayCount = 0
            return false
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        result = CGGetOnlineDisplayList(displayCount, &displays, &displayCount)
        guard result == .success else {
            return false
        }

        let tables = ColorTemperature.gammaTables(profile: profile)
        runtime.displayCount = Int(displayCount)

        var allSucceeded = true
        for display in displays {
            let setResult = tables.red.withUnsafeBufferPointer { redBuffer in
                tables.green.withUnsafeBufferPointer { greenBuffer in
                    tables.blue.withUnsafeBufferPointer { blueBuffer in
                        CGSetDisplayTransferByTable(
                            display,
                            UInt32(tables.red.count),
                            redBuffer.baseAddress,
                            greenBuffer.baseAddress,
                            blueBuffer.baseAddress
                        )
                    }
                }
            }

            if setResult != .success {
                allSucceeded = false
            }
        }

        return allSucceeded
    }

    private func installDisplayObservers() {
        guard !hasInstalledObservers else {
            return
        }
        hasInstalledObservers = true

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyCurrentPhase(animated: false)
            }
        }
    }

    private func scheduleTransition(to target: DisplayProfile) {
        transitionTask?.cancel()
        let start = runtime.lastAppliedProfile
        transitionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for step in 1...12 {
                if Task.isCancelled {
                    return
                }

                let progress = Double(step) / 12
                let profile = self.interpolatedProfile(from: start, to: target, progress: progress)
                self.runtime.lastAppliedProfile = profile
                if self.applyGamma(profile: profile) {
                    self.overlayController.clear()
                    self.runtime.usedOverlayFallback = false
                } else if self.currentSettings.useOverlayFallback {
                    self.overlayController.apply(profile: profile)
                    self.runtime.usedOverlayFallback = true
                }

                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    private func interpolatedProfile(from start: DisplayProfile, to target: DisplayProfile, progress: Double) -> DisplayProfile {
        let progress = min(max(progress, 0), 1)
        return DisplayProfile(
            kelvin: start.kelvin + (target.kelvin - start.kelvin) * progress,
            brightness: start.brightness + (target.brightness - start.brightness) * progress,
            dimOpacity: start.dimOpacity + (target.dimOpacity - start.dimOpacity) * progress
        )
    }

    private func clamped(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
