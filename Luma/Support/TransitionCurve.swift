import Foundation

/// Plans a perceptually smooth ramp between two display profiles.
///
/// Pure value type so the step math is unit-testable apart from the
/// gamma-table side effects in `DisplayController`.
struct TransitionCurve {
    var duration: TimeInterval
    var stepInterval: TimeInterval

    /// Default ramp used for schedule changes and user adjustments.
    static let standard = TransitionCurve(duration: 1.6, stepInterval: 1.0 / 30.0)

    var stepCount: Int {
        max(1, Int((duration / stepInterval).rounded(.up)))
    }

    func profile(from start: DisplayProfile, to target: DisplayProfile, step: Int) -> DisplayProfile {
        let clampedStep = min(max(step, 0), stepCount)
        if clampedStep == stepCount {
            return target
        }

        let progress = Self.easeInOut(Double(clampedStep) / Double(stepCount))
        return DisplayProfile.interpolated(from: start, to: target, progress: progress)
    }

    /// Smoothstep easing: zero velocity at both ends, where abrupt changes are most visible.
    static func easeInOut(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

extension DisplayProfile {
    /// Whether the difference from `other` is below the threshold of perception,
    /// so applying it (or animating to it) would be wasted work.
    func isApproximatelyEqual(to other: DisplayProfile) -> Bool {
        abs(kelvin - other.kelvin) < 1
            && abs(brightness - other.brightness) < 0.1
            && abs(dimOpacity - other.dimOpacity) < 0.1
    }
}
