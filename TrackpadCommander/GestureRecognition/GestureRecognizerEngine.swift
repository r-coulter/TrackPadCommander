import CoreGraphics
import Foundation

struct RecognitionMetrics: Hashable, Sendable {
    var fingerCount: Int
    var durationMs: Double
    var distance: CGFloat
    var velocity: CGFloat
    var confidence: Double
}

struct GestureEvent: Hashable, Sendable, Identifiable {
    var id: UUID
    var gesture: GestureID
    var deviceID: String
    var timestamp: Date
    var metrics: RecognitionMetrics

    init(
        id: UUID = UUID(),
        gesture: GestureID,
        deviceID: String,
        timestamp: Date = Date(),
        metrics: RecognitionMetrics
    ) {
        self.id = id
        self.gesture = gesture
        self.deviceID = deviceID
        self.timestamp = timestamp
        self.metrics = metrics
    }
}

final class GestureRecognizerEngine {
    private struct DeviceState {
        var startTimestamp: TimeInterval
        var lastTimestamp: TimeInterval
        var initialContacts: [Int: CGPoint]
        var lastContacts: [Int: CGPoint]
        var maxFingerCount: Int
        var maxTravel: CGFloat
        var initialCentroid: CGPoint
        var lastCentroid: CGPoint
        var initialSpread: CGFloat?
        var lastSpread: CGFloat?
    }

    private var deviceStates: [String: DeviceState] = [:]
    private var lastEmissions: [String: Date] = [:]

    func process(frame: TouchFrame) -> GestureEvent? {
        if frame.contacts.isEmpty {
            defer { deviceStates.removeValue(forKey: frame.deviceID) }
            guard let state = deviceStates[frame.deviceID] else { return nil }
            return finalize(deviceID: frame.deviceID, state: state, finalTimestamp: frame.timestamp)
        }

        let centroid = Self.centroid(for: frame.contacts)
        let spread = Self.spread(for: frame.contacts, centroid: centroid)

        if var state = deviceStates[frame.deviceID] {
            state.lastTimestamp = frame.timestamp
            state.lastCentroid = centroid
            state.lastSpread = spread
            state.maxFingerCount = max(state.maxFingerCount, frame.contacts.count)

            for contact in frame.contacts {
                if state.initialContacts[contact.identifier] == nil {
                    state.initialContacts[contact.identifier] = contact.normalizedPosition
                }

                state.lastContacts[contact.identifier] = contact.normalizedPosition
                if let start = state.initialContacts[contact.identifier] {
                    state.maxTravel = max(
                        state.maxTravel,
                        Self.distance(from: start, to: contact.normalizedPosition)
                    )
                }
            }

            deviceStates[frame.deviceID] = state
            return nil
        } else {
            deviceStates[frame.deviceID] = DeviceState(
                startTimestamp: frame.timestamp,
                lastTimestamp: frame.timestamp,
                initialContacts: Dictionary(uniqueKeysWithValues: frame.contacts.map { ($0.identifier, $0.normalizedPosition) }),
                lastContacts: Dictionary(uniqueKeysWithValues: frame.contacts.map { ($0.identifier, $0.normalizedPosition) }),
                maxFingerCount: frame.contacts.count,
                maxTravel: 0,
                initialCentroid: centroid,
                lastCentroid: centroid,
                initialSpread: spread,
                lastSpread: spread
            )
            return nil
        }
    }

    private func finalize(deviceID: String, state: DeviceState, finalTimestamp: TimeInterval) -> GestureEvent? {
        let durationMs = max((finalTimestamp - state.startTimestamp) * 1_000, 1)
        let deltaX = state.lastCentroid.x - state.initialCentroid.x
        let deltaY = state.lastCentroid.y - state.initialCentroid.y
        let displacement = hypot(deltaX, deltaY)
        let velocity = displacement / CGFloat(durationMs / 1_000)
        let metrics = RecognitionMetrics(
            fingerCount: state.maxFingerCount,
            durationMs: durationMs,
            distance: displacement,
            velocity: velocity,
            confidence: 0.5
        )

        if let pinchEvent = classifyPinch(deviceID: deviceID, state: state, metrics: metrics) {
            return pinchEvent
        }

        if let swipeEvent = classifySwipe(deviceID: deviceID, state: state, metrics: metrics, deltaX: deltaX, deltaY: deltaY) {
            return swipeEvent
        }

        if let tapEvent = classifyTap(deviceID: deviceID, state: state, metrics: metrics) {
            return tapEvent
        }

        return nil
    }

    private func classifyTap(deviceID: String, state: DeviceState, metrics: RecognitionMetrics) -> GestureEvent? {
        guard metrics.durationMs <= GestureThresholds.tapMaxDurationMs,
              state.maxTravel <= GestureThresholds.tapMaxTravel else {
            return nil
        }

        let gesture: GestureID?
        switch state.maxFingerCount {
        case 2: gesture = .twoFingerTap
        case 3: gesture = .threeFingerTap
        case 4: gesture = .fourFingerTap
        default: gesture = nil
        }

        guard let gesture else { return nil }
        return emit(
            gesture: gesture,
            deviceID: deviceID,
            metrics: RecognitionMetrics(
                fingerCount: metrics.fingerCount,
                durationMs: metrics.durationMs,
                distance: state.maxTravel,
                velocity: metrics.velocity,
                confidence: 0.95
            )
        )
    }

    private func classifySwipe(
        deviceID: String,
        state: DeviceState,
        metrics: RecognitionMetrics,
        deltaX: CGFloat,
        deltaY: CGFloat
    ) -> GestureEvent? {
        guard state.maxFingerCount == 3 || state.maxFingerCount == 4 else { return nil }

        let primaryIsHorizontal = abs(deltaX) >= abs(deltaY)
        let primary = primaryIsHorizontal ? abs(deltaX) : abs(deltaY)
        let secondary = primaryIsHorizontal ? abs(deltaY) : abs(deltaX)

        guard primary >= GestureThresholds.swipeMinTravel,
              secondary <= primary * GestureThresholds.swipeOffAxisRatio else {
            return nil
        }

        let gesture: GestureID
        if state.maxFingerCount == 3 {
            if primaryIsHorizontal {
                gesture = deltaX < 0 ? .threeFingerSwipeLeft : .threeFingerSwipeRight
            } else {
                gesture = deltaY < 0 ? .threeFingerSwipeDown : .threeFingerSwipeUp
            }
        } else {
            if primaryIsHorizontal {
                gesture = deltaX < 0 ? .fourFingerSwipeLeft : .fourFingerSwipeRight
            } else {
                gesture = deltaY < 0 ? .fourFingerSwipeDown : .fourFingerSwipeUp
            }
        }

        return emit(
            gesture: gesture,
            deviceID: deviceID,
            metrics: RecognitionMetrics(
                fingerCount: metrics.fingerCount,
                durationMs: metrics.durationMs,
                distance: primary,
                velocity: metrics.velocity,
                confidence: 0.85
            )
        )
    }

    private func classifyPinch(deviceID: String, state: DeviceState, metrics: RecognitionMetrics) -> GestureEvent? {
        guard state.maxFingerCount == 2,
              let initialSpread = state.initialSpread,
              let lastSpread = state.lastSpread,
              initialSpread > 0 else {
            return nil
        }

        let scaleDelta = (lastSpread - initialSpread) / initialSpread
        guard abs(scaleDelta) >= GestureThresholds.pinchScaleDelta else {
            return nil
        }

        let gesture: GestureID = scaleDelta < 0 ? .twoFingerPinchIn : .twoFingerPinchOut
        return emit(
            gesture: gesture,
            deviceID: deviceID,
            metrics: RecognitionMetrics(
                fingerCount: metrics.fingerCount,
                durationMs: metrics.durationMs,
                distance: abs(scaleDelta),
                velocity: metrics.velocity,
                confidence: 0.9
            )
        )
    }

    private func emit(gesture: GestureID, deviceID: String, metrics: RecognitionMetrics) -> GestureEvent? {
        let key = "\(deviceID)|\(gesture.rawValue)"
        let now = Date()

        if let lastEmission = lastEmissions[key],
           now.timeIntervalSince(lastEmission) * 1_000 < GestureThresholds.recognitionCooldownMs {
            return nil
        }

        lastEmissions[key] = now
        return GestureEvent(gesture: gesture, deviceID: deviceID, timestamp: now, metrics: metrics)
    }

    private static func centroid(for contacts: [TouchContact]) -> CGPoint {
        let count = CGFloat(max(contacts.count, 1))
        let total = contacts.reduce(CGPoint.zero) { partial, contact in
            CGPoint(x: partial.x + contact.normalizedPosition.x, y: partial.y + contact.normalizedPosition.y)
        }
        return CGPoint(x: total.x / count, y: total.y / count)
    }

    private static func spread(for contacts: [TouchContact], centroid: CGPoint) -> CGFloat? {
        guard contacts.count >= 2 else { return nil }
        let total = contacts.reduce(CGFloat.zero) { partial, contact in
            partial + distance(from: centroid, to: contact.normalizedPosition)
        }
        return total / CGFloat(contacts.count)
    }

    private static func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(rhs.x - lhs.x, rhs.y - lhs.y)
    }
}
