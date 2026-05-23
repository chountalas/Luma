import AppKit

@MainActor
final class OverlayController {
    private var windows: [NSScreen: NSWindow] = [:]

    func apply(profile: DisplayProfile) {
        let color = overlayColor(for: profile)
        let screens = Set(NSScreen.screens)

        for screen in screens {
            let window = windows[screen] ?? makeWindow(for: screen)
            window.setFrame(screen.frame, display: true)
            window.backgroundColor = color
            window.orderFrontRegardless()
            windows[screen] = window
        }

        for (screen, window) in windows where !screens.contains(screen) {
            window.close()
            windows.removeValue(forKey: screen)
        }
    }

    func clear() {
        windows.values.forEach { $0.close() }
        windows.removeAll()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        return window
    }

    private func overlayColor(for profile: DisplayProfile) -> NSColor {
        let multipliers = ColorTemperature.rgbMultipliers(kelvin: profile.kelvin)
        let warmthAlpha = min(max((6500 - profile.kelvin) / 6500, 0), 0.55)
        let dimAlpha = profile.normalizedDimOpacity
        let alpha = min(max(warmthAlpha + dimAlpha, 0.02), 0.85)

        return NSColor(
            calibratedRed: CGFloat(max(0.2, multipliers.red)),
            green: CGFloat(max(0.05, multipliers.green * 0.75)),
            blue: CGFloat(max(0, multipliers.blue * 0.35)),
            alpha: CGFloat(alpha)
        )
    }
}

