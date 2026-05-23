import Foundation

struct RuntimeState: Equatable {
    var isPaused = false
    var activePhase: ActivePhase = .day
    var lastAppliedProfile = DisplayProfile.dayDefault
    var displayCount = 0
    var usedOverlayFallback = false
    var lastError: String?
}

