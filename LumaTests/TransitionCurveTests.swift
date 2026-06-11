import XCTest
@testable import Luma

final class TransitionCurveTests: XCTestCase {
    func testEaseInOutBoundaries() {
        XCTAssertEqual(TransitionCurve.easeInOut(0), 0, accuracy: 1e-9)
        XCTAssertEqual(TransitionCurve.easeInOut(1), 1, accuracy: 1e-9)
        XCTAssertEqual(TransitionCurve.easeInOut(0.5), 0.5, accuracy: 1e-9)
    }

    func testEaseInOutClampsOutOfRangeInput() {
        XCTAssertEqual(TransitionCurve.easeInOut(-2), 0, accuracy: 1e-9)
        XCTAssertEqual(TransitionCurve.easeInOut(3), 1, accuracy: 1e-9)
    }

    func testEaseInOutIsMonotonicallyIncreasing() {
        var previous = TransitionCurve.easeInOut(0)
        for index in 1...100 {
            let value = TransitionCurve.easeInOut(Double(index) / 100)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
    }

    func testEaseInOutStartsAndEndsGently() {
        // The first and last 10% of the ramp should move less than a linear ramp would.
        XCTAssertLessThan(TransitionCurve.easeInOut(0.1), 0.1)
        XCTAssertGreaterThan(TransitionCurve.easeInOut(0.9), 0.9)
    }

    func testStandardCurveStepCount() {
        let curve = TransitionCurve.standard
        XCTAssertGreaterThanOrEqual(curve.stepCount, 30, "Fewer steps than this reads as a visible staircase")
        XCTAssertEqual(curve.stepCount, Int((curve.duration / curve.stepInterval).rounded(.up)))
    }

    func testFinalStepLandsExactlyOnTarget() {
        let curve = TransitionCurve.standard
        let start = DisplayProfile(kelvin: 5600, brightness: 100, dimOpacity: 0)
        let target = DisplayProfile(kelvin: 3200, brightness: 90, dimOpacity: 10)
        let final = curve.profile(from: start, to: target, step: curve.stepCount)
        XCTAssertEqual(final, target)
    }

    func testFirstStepDoesNotJump() {
        // Regression: the old implementation jumped 35% of the way instantly.
        let curve = TransitionCurve.standard
        let start = DisplayProfile(kelvin: 6500, brightness: 100, dimOpacity: 0)
        let target = DisplayProfile(kelvin: 2500, brightness: 100, dimOpacity: 0)
        let first = curve.profile(from: start, to: target, step: 1)
        let totalDelta = abs(target.kelvin - start.kelvin)
        let firstDelta = abs(first.kelvin - start.kelvin)
        XCTAssertLessThan(firstDelta / totalDelta, 0.05)
    }

    func testKelvinSequenceIsMonotonic() {
        let curve = TransitionCurve.standard
        let start = DisplayProfile(kelvin: 5600, brightness: 100, dimOpacity: 0)
        let target = DisplayProfile(kelvin: 3200, brightness: 96, dimOpacity: 3)
        var previousKelvin = start.kelvin
        for step in 1...curve.stepCount {
            let profile = curve.profile(from: start, to: target, step: step)
            XCTAssertLessThanOrEqual(profile.kelvin, previousKelvin)
            previousKelvin = profile.kelvin
        }
    }

    func testApproximateEqualityIgnoresImperceptibleDeltas() {
        let base = DisplayProfile(kelvin: 4300, brightness: 100, dimOpacity: 0)
        let nearlyIdentical = DisplayProfile(kelvin: 4300.4, brightness: 100.05, dimOpacity: 0.05)
        let different = DisplayProfile(kelvin: 4350, brightness: 100, dimOpacity: 0)
        XCTAssertTrue(base.isApproximatelyEqual(to: nearlyIdentical))
        XCTAssertFalse(base.isApproximatelyEqual(to: different))
    }
}
