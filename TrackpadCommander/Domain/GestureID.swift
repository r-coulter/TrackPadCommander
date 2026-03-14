import Foundation

enum GestureID: String, Codable, CaseIterable, Identifiable, Hashable {
    case twoFingerTap
    case threeFingerTap
    case fourFingerTap
    case threeFingerSwipeLeft
    case threeFingerSwipeRight
    case threeFingerSwipeUp
    case threeFingerSwipeDown
    case fourFingerSwipeLeft
    case fourFingerSwipeRight
    case fourFingerSwipeUp
    case fourFingerSwipeDown
    case twoFingerPinchIn
    case twoFingerPinchOut

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twoFingerTap: "Two-Finger Tap"
        case .threeFingerTap: "Three-Finger Tap"
        case .fourFingerTap: "Four-Finger Tap"
        case .threeFingerSwipeLeft: "Three-Finger Swipe Left"
        case .threeFingerSwipeRight: "Three-Finger Swipe Right"
        case .threeFingerSwipeUp: "Three-Finger Swipe Up"
        case .threeFingerSwipeDown: "Three-Finger Swipe Down"
        case .fourFingerSwipeLeft: "Four-Finger Swipe Left"
        case .fourFingerSwipeRight: "Four-Finger Swipe Right"
        case .fourFingerSwipeUp: "Four-Finger Swipe Up"
        case .fourFingerSwipeDown: "Four-Finger Swipe Down"
        case .twoFingerPinchIn: "Two-Finger Pinch In"
        case .twoFingerPinchOut: "Two-Finger Pinch Out"
        }
    }

    var fingerCount: Int {
        switch self {
        case .twoFingerTap, .twoFingerPinchIn, .twoFingerPinchOut:
            2
        case .threeFingerTap, .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown:
            3
        case .fourFingerTap, .fourFingerSwipeLeft, .fourFingerSwipeRight, .fourFingerSwipeUp, .fourFingerSwipeDown:
            4
        }
    }
}
