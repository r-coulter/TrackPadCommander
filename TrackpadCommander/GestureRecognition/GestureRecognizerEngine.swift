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
    var threeFingerTapSensitivity = 1.0

    private struct DeviceState {
        var startTimestamp: TimeInterval
        var lastTimestamp: TimeInterval
        var fingerCount: Int
        var initialCentroid: CGPoint
        var lastCentroid: CGPoint
        var maxCentroidTravel: CGFloat
        var initialSpread: CGFloat?
        var lastSpread: CGFloat?
        var stabilizationDeadline: TimeInterval
    }

    private var deviceStates: [String: DeviceState] = [:]
    private var lastEmissions: [String: Date] = [:]

    private var normalizedThreeFingerTapSensitivity: Double {
        min(max(threeFingerTapSensitivity, 0.75), 1.5)
    }

    func process(frame: TouchFrame) -> GestureEvent? {
        if frame.contacts.isEmpty {
            defer { deviceStates.removeValue(forKey: frame.deviceID) }
            guard let state = deviceStates[frame.deviceID] else { return nil }
            return finalize(deviceID: frame.deviceID, state: state, finalTimestamp: state.lastTimestamp)
        }

        let centroid = Self.centroid(for: frame.contacts)
        let spread = Self.spread(for: frame.contacts, centroid: centroid)

        if var state = deviceStates[frame.deviceID] {
            if frame.contacts.count > state.fingerCount {
                state = DeviceState(
                    startTimestamp: frame.timestamp,
                    lastTimestamp: frame.timestamp,
                    fingerCount: frame.contacts.count,
                    initialCentroid: centroid,
                    lastCentroid: centroid,
                    maxCentroidTravel: 0,
                    initialSpread: spread,
                    lastSpread: spread,
                    stabilizationDeadline: frame.timestamp + (GestureThresholds.landingStabilizationMs / 1_000)
                )
                deviceStates[frame.deviceID] = state
                return nil
            }

            if frame.timestamp <= state.stabilizationDeadline {
                state.startTimestamp = frame.timestamp
                state.lastTimestamp = frame.timestamp
                state.initialCentroid = centroid
                state.lastCentroid = centroid
                state.maxCentroidTravel = 0
                state.initialSpread = spread
                state.lastSpread = spread
                deviceStates[frame.deviceID] = state
                return nil
            }

            if frame.contacts.count < state.fingerCount {
                defer { deviceStates.removeValue(forKey: frame.deviceID) }
                return finalize(deviceID: frame.deviceID, state: state, finalTimestamp: state.lastTimestamp)
            }

            state.lastTimestamp = frame.timestamp
            state.lastCentroid = centroid
            state.lastSpread = spread
            state.maxCentroidTravel = max(
                state.maxCentroidTravel,
                Self.distance(from: state.initialCentroid, to: centroid)
            )

            deviceStates[frame.deviceID] = state
            return nil
        } else {
            deviceStates[frame.deviceID] = DeviceState(
                startTimestamp: frame.timestamp,
                lastTimestamp: frame.timestamp,
                fingerCount: frame.contacts.count,
                initialCentroid: centroid,
                lastCentroid: centroid,
                maxCentroidTravel: 0,
                initialSpread: spread,
                lastSpread: spread,
                stabilizationDeadline: frame.timestamp + (GestureThresholds.landingStabilizationMs / 1_000)
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
            fingerCount: state.fingerCount,
            durationMs: durationMs,
            distance: displacement,
            velocity: velocity,
            confidence: 0.5
        )

        if let pinchEvent = classifyPinch(deviceID: deviceID, state: state, metrics: metrics) {
            return pinchEvent
        }

        if let directTapEvent = classifyDirectThreeFingerTap(deviceID: deviceID, state: state, metrics: metrics) {
            return directTapEvent
        }

        if let swipeEvent = classifySwipe(deviceID: deviceID, state: state, metrics: metrics, deltaX: deltaX, deltaY: deltaY) {
            return swipeEvent
        }

        if let tapEvent = classifyTap(deviceID: deviceID, state: state, metrics: metrics) {
            return tapEvent
        }

        return nil
    }

    private func classifyDirectThreeFingerTap(
        deviceID: String,
        state: DeviceState,
        metrics: RecognitionMetrics
    ) -> GestureEvent? {
        let durationLimit = GestureThresholds.threeFingerTapDirectMaxDurationMs * normalizedThreeFingerTapSensitivity
        let travelLimit = GestureThresholds.threeFingerTapDirectMaxTravel * normalizedThreeFingerTapSensitivity

        guard state.fingerCount == 3,
              metrics.durationMs <= durationLimit,
              state.maxCentroidTravel <= travelLimit else {
            return nil
        }

        return emit(
            gesture: .threeFingerTap,
            deviceID: deviceID,
            metrics: RecognitionMetrics(
                fingerCount: 3,
                durationMs: metrics.durationMs,
                distance: state.maxCentroidTravel,
                velocity: metrics.velocity,
                confidence: 0.8
            )
        )
    }

    private func classifyTap(deviceID: String, state: DeviceState, metrics: RecognitionMetrics) -> GestureEvent? {
        let durationLimit = state.fingerCount == 3
            ? GestureThresholds.tapMaxDurationMs * normalizedThreeFingerTapSensitivity
            : GestureThresholds.tapMaxDurationMs
        let travelLimit = state.fingerCount == 3
            ? GestureThresholds.tapMaxTravel * normalizedThreeFingerTapSensitivity
            : GestureThresholds.tapMaxTravel

        guard metrics.durationMs <= durationLimit,
              state.maxCentroidTravel <= travelLimit else {
            return nil
        }

        let gesture: GestureID?
        switch state.fingerCount {
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
                distance: state.maxCentroidTravel,
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
        guard state.fingerCount == 3 || state.fingerCount == 4 else { return nil }

        let primaryIsHorizontal = abs(deltaX) >= abs(deltaY)
        let primary = primaryIsHorizontal ? abs(deltaX) : abs(deltaY)
        let secondary = primaryIsHorizontal ? abs(deltaY) : abs(deltaX)

        guard primary >= GestureThresholds.swipeMinTravel,
              secondary <= primary * GestureThresholds.swipeOffAxisRatio else {
            return nil
        }

        let gesture: GestureID
        if state.fingerCount == 3 {
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
        guard state.fingerCount == 2,
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
