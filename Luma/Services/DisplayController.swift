import AppKit
import CoreGraphics
import Foundation
import os

@MainActor
final class DisplayController: ObservableObject {
    @Published private(set) var runtime = RuntimeState()

    /// Gamma must fail this many times in a row before the overlay engages, so a
    /// single rejection during display sleep/reconfiguration doesn't flash a tint.
    private static let overlayFailureThreshold = 3

    private let logger = Logger(subsystem: "com.connorhountalas.Luma", category: "display")
    private let overlayController = OverlayController()
    private var currentSettings = LumaSettings()
    private var timer: Timer?
    private var hasInstalledObservers = false
    private var transitionTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var isTransitioning = false
    private var consecutiveGammaFailures = 0
    private var displayMaintenanceActivity: NSObjectProtocol?

    func start(settings: LumaSettings) {
        currentSettings = settings
        beginDisplayMaintenanceActivity()
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

    func resetDisplay() {
        transitionTask?.cancel()
        retryTask?.cancel()
        CGDisplayRestoreColorSyncSettings()
        overlayController.clear()
        runtime.usedOverlayFallback = false
        runtime.lastAppliedProfile = .neutral
        consecutiveGammaFailures = 0
    }

    private func scheduleTick() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.applyCurrentPhase(animated: true)
            }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func beginDisplayMaintenanceActivity() {
        guard displayMaintenanceActivity == nil else {
            return
        }

        displayMaintenanceActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Keep Luma display adjustments active"
        )
    }

    private func applyCurrentPhase(animated: Bool) {
        if runtime.isPaused {
            let alreadyPaused = runtime.activePhase == .paused
            runtime.activePhase = .paused
            guard !alreadyPaused else {
                return
            }

            if animated {
                transition(to: .neutral) { [weak self] in
                    self?.finishPauseReset()
                }
            } else {
                transitionTask?.cancel()
                finishPauseReset()
            }
            return
        }

        let scheduled = currentSettings.scheduledProfile(at: Date())
        runtime.activePhase = scheduled.phase
        let target = scheduled.profile

        if !animated {
            transitionTask?.cancel()
            runtime.lastAppliedProfile = target
            applyProfile(target)
            return
        }

        if !isTransitioning && target.isApproximatelyEqual(to: runtime.lastAppliedProfile) {
            // Re-assert gamma so system resets get corrected, but skip the ramp.
            runtime.lastAppliedProfile = target
            applyProfile(target)
            return
        }

        transition(to: target)
    }

    private func finishPauseReset() {
        CGDisplayRestoreColorSyncSettings()
        overlayController.clear()
        runtime.usedOverlayFallback = false
        runtime.lastAppliedProfile = .neutral
        consecutiveGammaFailures = 0
    }

    private func transition(to target: DisplayProfile, completion: (() -> Void)? = nil) {
        transitionTask?.cancel()
        let curve = TransitionCurve.standard
        let start = runtime.lastAppliedProfile
        transitionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isTransitioning = true
            defer { self.isTransitioning = false }

            for step in 1...curve.stepCount {
                if Task.isCancelled {
                    return
                }

                let profile = curve.profile(from: start, to: target, step: step)
                self.runtime.lastAppliedProfile = profile
                self.applyProfile(profile)

                if step < curve.stepCount {
                    try? await Task.sleep(for: .seconds(curve.stepInterval))
                }
            }

            completion?()
        }
    }

    private func applyProfile(_ profile: DisplayProfile) {
        if applyGamma(profile: profile) {
            consecutiveGammaFailures = 0
            retryTask?.cancel()
            if runtime.usedOverlayFallback {
                overlayController.clear()
                runtime.usedOverlayFallback = false
                logger.info("Gamma restored; overlay fallback cleared")
            }
            runtime.lastError = nil
            return
        }

        consecutiveGammaFailures += 1
        logger.warning("Gamma apply failed (\(self.consecutiveGammaFailures, privacy: .public) consecutive)")

        guard consecutiveGammaFailures >= Self.overlayFailureThreshold else {
            scheduleFailureRetry()
            return
        }

        if currentSettings.useOverlayFallback {
            if !runtime.usedOverlayFallback {
                logger.warning("Engaging overlay fallback")
            }
            overlayController.apply(profile: profile)
            runtime.usedOverlayFallback = true
            runtime.lastError = "Display rejected direct gamma changes; using overlay fallback."
        } else {
            runtime.lastError = "Display rejected direct gamma changes and overlay fallback is disabled."
        }
    }

    /// Retries quickly after a sub-threshold failure so a genuinely broken display
    /// reaches the overlay fallback in ~1s instead of waiting out 15s timer ticks.
    private func scheduleFailureRetry() {
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled, !self.isTransitioning else {
                return
            }
            self.applyCurrentPhase(animated: false)
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

        var attempted = 0
        var failed = 0
        for display in displays {
            // A sleeping display rejects gamma writes; that is not a real failure.
            guard CGDisplayIsAsleep(display) == 0 else {
                continue
            }
            attempted += 1

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
                failed += 1
            }
        }

        return failed == 0
    }

    private func installDisplayObservers() {
        guard !hasInstalledObservers else {
            return
        }
        hasInstalledObservers = true

        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            guard !flags.contains(.beginConfigurationFlag) else {
                return
            }
            NotificationCenter.default.post(name: .lumaDisplayReconfigured, object: nil)
        }, nil)

        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        let workspaceNotifications: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]

        for notificationName in workspaceNotifications {
            workspaceNotificationCenter.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleRecoveryReapply(reason: notificationName.rawValue)
                }
            }
        }

        let appNotifications: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            .lumaDisplayReconfigured
        ]

        for notificationName in appNotifications {
            NotificationCenter.default.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleRecoveryReapply(reason: notificationName.rawValue)
                }
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRecoveryReapply(reason: "screenIsUnlocked")
            }
        }
    }

    private func scheduleRecoveryReapply(reason: String) {
        logger.info("Recovery reapply scheduled: \(reason, privacy: .public)")
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            let delays: [Duration] = [
                .zero,
                .milliseconds(250),
                .seconds(1),
                .seconds(3),
                .seconds(8)
            ]

            for delay in delays {
                if Task.isCancelled {
                    return
                }

                if delay != .zero {
                    try? await Task.sleep(for: delay)
                }

                guard let self, !Task.isCancelled else {
                    return
                }

                // An in-flight ramp is already writing gamma every step;
                // snapping here would visibly interrupt it.
                if self.isTransitioning {
                    continue
                }

                self.applyCurrentPhase(animated: false)
            }
        }
    }
}

extension Notification.Name {
    static let lumaDisplayReconfigured = Notification.Name("LumaDisplayReconfigured")
}
