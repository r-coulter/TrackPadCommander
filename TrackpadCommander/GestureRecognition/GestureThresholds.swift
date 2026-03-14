import Foundation

enum GestureThresholds {
    static let tapMaxDurationMs: Double = 150
    static let tapMaxTravel: CGFloat = 0.08
    static let swipeMinTravel: CGFloat = 0.18
    static let swipeOffAxisRatio: CGFloat = 0.35
    static let pinchScaleDelta: CGFloat = 0.12
    static let recognitionCooldownMs: Double = 250
}
