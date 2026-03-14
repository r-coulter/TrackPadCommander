import Foundation

enum GestureThresholds {
    static let landingStabilizationMs: Double = 35
    static let tapMaxDurationMs: Double = 220
    static let tapMaxTravel: CGFloat = 0.12
    static let threeFingerTapDirectMaxDurationMs: Double = 120
    static let threeFingerTapDirectMaxTravel: CGFloat = 0.30
    static let swipeMinTravel: CGFloat = 0.18
    static let swipeOffAxisRatio: CGFloat = 0.35
    static let pinchScaleDelta: CGFloat = 0.12
    static let recognitionCooldownMs: Double = 250
    static let threeFingerTapFallbackMaxDurationMs: Double = 320
    static let threeFingerTapFallbackMaxDistance: CGFloat = 0.75
    static let threeFingerTapSequenceFallbackWindowMs: Double = 250
}
