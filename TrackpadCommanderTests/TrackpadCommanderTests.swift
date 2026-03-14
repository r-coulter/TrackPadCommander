import XCTest
@testable import TrackpadCommander

final class TrackpadCommanderTests: XCTestCase {
    func testTapRecognitionEmitsThreeFingerTap() {
        let engine = GestureRecognizerEngine()
        let start = 1_000.0

        _ = engine.process(frame: makeFrame(
            timestamp: start,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.2, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.4, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.6, y: 0.2), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.08,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.21, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.41, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.61, y: 0.2), normalizedVelocity: .zero),
            ]
        ))

        let event = engine.process(frame: makeFrame(timestamp: start + 0.09, contacts: []))
        XCTAssertEqual(event?.gesture, .threeFingerTap)
    }

    func testSwipeRecognitionRejectsDiagonalNoise() {
        let engine = GestureRecognizerEngine()
        let start = 2_000.0

        _ = engine.process(frame: makeFrame(
            timestamp: start,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.2, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.4, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.6, y: 0.2), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.2,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.45, y: 0.45), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.65, y: 0.45), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.85, y: 0.45), normalizedVelocity: .zero),
            ]
        ))

        let event = engine.process(frame: makeFrame(timestamp: start + 0.22, contacts: []))
        XCTAssertNil(event)
    }

    func testPinchRecognitionEmitsPinchIn() {
        let engine = GestureRecognizerEngine()
        let start = 3_000.0

        _ = engine.process(frame: makeFrame(
            timestamp: start,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.2, y: 0.5), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.8, y: 0.5), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.1,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.35, y: 0.5), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.65, y: 0.5), normalizedVelocity: .zero),
            ]
        ))

        let event = engine.process(frame: makeFrame(timestamp: start + 0.12, contacts: []))
        XCTAssertEqual(event?.gesture, .twoFingerPinchIn)
    }

    func testTapRecognitionDoesNotDependOnStableTouchIdentifiers() {
        let engine = GestureRecognizerEngine()
        let start = 4_000.0

        _ = engine.process(frame: makeFrame(
            timestamp: start,
            contacts: [
                .init(identifier: 0, normalizedPosition: CGPoint(x: 0.2, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 0, normalizedPosition: CGPoint(x: 0.4, y: 0.2), normalizedVelocity: .zero),
                .init(identifier: 0, normalizedPosition: CGPoint(x: 0.6, y: 0.2), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.04,
            contacts: [
                .init(identifier: 5, normalizedPosition: CGPoint(x: 0.205, y: 0.205), normalizedVelocity: .zero),
                .init(identifier: 7, normalizedPosition: CGPoint(x: 0.405, y: 0.205), normalizedVelocity: .zero),
                .init(identifier: 9, normalizedPosition: CGPoint(x: 0.605, y: 0.205), normalizedVelocity: .zero),
            ]
        ))

        let event = engine.process(frame: makeFrame(timestamp: start + 0.08, contacts: []))
        XCTAssertEqual(event?.gesture, .threeFingerTap)
    }

    func testTapRecognitionIgnoresFingerLandingMotion() {
        let engine = GestureRecognizerEngine()
        let start = 5_000.0

        _ = engine.process(frame: makeFrame(
            timestamp: start,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.25, y: 0.30), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.03,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.25, y: 0.30), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.45, y: 0.30), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.05,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.25, y: 0.30), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.45, y: 0.30), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.65, y: 0.30), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.13,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.255, y: 0.305), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.455, y: 0.305), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.655, y: 0.305), normalizedVelocity: .zero),
            ]
        ))

        let event = engine.process(frame: makeFrame(
            timestamp: start + 0.16,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.26, y: 0.31), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.46, y: 0.31), normalizedVelocity: .zero),
            ]
        ))

        XCTAssertEqual(event?.gesture, .threeFingerTap)
    }

    func testTapRecognitionIgnoresSimultaneousLandingMotion() {
        let engine = GestureRecognizerEngine()
        let start = 5_500.0

        _ = engine.process(frame: makeFrame(
            timestamp: start,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.18, y: 0.24), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.38, y: 0.24), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.58, y: 0.24), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.02,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.33, y: 0.28), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.53, y: 0.28), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.73, y: 0.28), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.08,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.335, y: 0.285), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.535, y: 0.285), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.735, y: 0.285), normalizedVelocity: .zero),
            ]
        ))

        let event = engine.process(frame: makeFrame(timestamp: start + 0.10, contacts: []))
        XCTAssertEqual(event?.gesture, .threeFingerTap)
    }

    func testTapRecognitionPrefersShortThreeFingerTapOverSwipe() {
        let engine = GestureRecognizerEngine()
        let start = 5_800.0

        _ = engine.process(frame: makeFrame(
            timestamp: start,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.25, y: 0.30), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.45, y: 0.30), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.65, y: 0.30), normalizedVelocity: .zero),
            ]
        ))
        _ = engine.process(frame: makeFrame(
            timestamp: start + 0.07,
            contacts: [
                .init(identifier: 1, normalizedPosition: CGPoint(x: 0.34, y: 0.30), normalizedVelocity: .zero),
                .init(identifier: 2, normalizedPosition: CGPoint(x: 0.54, y: 0.30), normalizedVelocity: .zero),
                .init(identifier: 3, normalizedPosition: CGPoint(x: 0.74, y: 0.30), normalizedVelocity: .zero),
            ]
        ))

        let event = engine.process(frame: makeFrame(timestamp: start + 0.09, contacts: []))
        XCTAssertEqual(event?.gesture, .threeFingerTap)
    }

    @MainActor
    func testThreeFingerTapFallbackFromSwipeThenTwoFingerTap() {
        let previousEvent = GestureEvent(
            gesture: .threeFingerSwipeLeft,
            deviceID: "device",
            timestamp: Date(timeIntervalSinceReferenceDate: 10),
            metrics: RecognitionMetrics(
                fingerCount: 3,
                durationMs: 120,
                distance: 0.2,
                velocity: 1.5,
                confidence: 0.85
            )
        )
        let rawEvent = GestureEvent(
            gesture: .twoFingerTap,
            deviceID: "device",
            timestamp: Date(timeIntervalSinceReferenceDate: 10.08),
            metrics: RecognitionMetrics(
                fingerCount: 2,
                durationMs: 1,
                distance: 0,
                velocity: 0,
                confidence: 0.95
            )
        )

        let resolved = AppState.resolveGestureFallback(
            rawEvent: rawEvent,
            previousEvent: previousEvent,
            enabledGestures: [.threeFingerTap]
        )

        XCTAssertEqual(resolved.gesture, .threeFingerTap)
        XCTAssertEqual(resolved.metrics.fingerCount, 3)
    }

    @MainActor
    func testThreeFingerTapFallbackAllowsLongerSwipeWhenNoSwipeBindingsExist() {
        let previousEvent = GestureEvent(
            gesture: .threeFingerSwipeRight,
            deviceID: "device",
            timestamp: Date(timeIntervalSinceReferenceDate: 20),
            metrics: RecognitionMetrics(
                fingerCount: 3,
                durationMs: 688,
                distance: 0.25,
                velocity: 0.8,
                confidence: 0.85
            )
        )
        let rawEvent = GestureEvent(
            gesture: .twoFingerTap,
            deviceID: "device",
            timestamp: Date(timeIntervalSinceReferenceDate: 20.03),
            metrics: RecognitionMetrics(
                fingerCount: 2,
                durationMs: 1,
                distance: 0,
                velocity: 0,
                confidence: 0.95
            )
        )

        let resolved = AppState.resolveGestureFallback(
            rawEvent: rawEvent,
            previousEvent: previousEvent,
            enabledGestures: [.threeFingerTap]
        )

        XCTAssertEqual(resolved.gesture, .threeFingerTap)
    }

    @MainActor
    func testThreeFingerTapFallbackReinterpretsShortSwipeDirectly() {
        let rawEvent = GestureEvent(
            gesture: .threeFingerSwipeRight,
            deviceID: "device",
            timestamp: Date(timeIntervalSinceReferenceDate: 30),
            metrics: RecognitionMetrics(
                fingerCount: 3,
                durationMs: 120,
                distance: 0.22,
                velocity: 1.1,
                confidence: 0.85
            )
        )

        let resolved = AppState.resolveGestureFallback(
            rawEvent: rawEvent,
            previousEvent: nil,
            enabledGestures: [.threeFingerTap]
        )

        XCTAssertEqual(resolved.gesture, .threeFingerTap)
    }

    @MainActor
    func testThreeFingerTapFallbackReinterpretsLongerSwipeLikeTapDirectly() {
        let rawEvent = GestureEvent(
            gesture: .threeFingerSwipeLeft,
            deviceID: "device",
            timestamp: Date(timeIntervalSinceReferenceDate: 40),
            metrics: RecognitionMetrics(
                fingerCount: 3,
                durationMs: 151,
                distance: 0.62,
                velocity: 1.0,
                confidence: 0.85
            )
        )

        let resolved = AppState.resolveGestureFallback(
            rawEvent: rawEvent,
            previousEvent: nil,
            enabledGestures: [.threeFingerTap]
        )

        XCTAssertEqual(resolved.gesture, .threeFingerTap)
        XCTAssertEqual(resolved.metrics.fingerCount, 3)
    }

    @MainActor
    func testThreeFingerTapFallbackReinterpretsShortSwipeWithoutDistanceCap() {
        let rawEvent = GestureEvent(
            gesture: .threeFingerSwipeRight,
            deviceID: "device",
            timestamp: Date(timeIntervalSinceReferenceDate: 45),
            metrics: RecognitionMetrics(
                fingerCount: 3,
                durationMs: 95,
                distance: 1.1,
                velocity: 1.3,
                confidence: 0.85
            )
        )

        let resolved = AppState.resolveGestureFallback(
            rawEvent: rawEvent,
            previousEvent: nil,
            enabledGestures: [.threeFingerTap]
        )

        XCTAssertEqual(resolved.gesture, .threeFingerTap)
    }

    func testConfigStoreRoundTrip() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ConfigStore(baseDirectoryURL: tempDirectory)
        let original = AppConfig.default

        try store.save(original)
        let loaded = try store.load()

        XCTAssertEqual(loaded, original)
    }

    func testConfigDecodeBackfillsNewDefaults() throws {
        let json = """
        {
          "bindings": [],
          "storedConflictRestores": [],
          "launchAtLogin": false,
          "loggingEnabled": true,
          "showNotifications": false
        }
        """

        let decoded = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.threeFingerTapSensitivity, 1.0)
        XCTAssertFalse(decoded.gestureDiagnosticsEnabled)
    }

    func testConflictRuleSelectionIncludesThreeFingerTap() {
        let rules = ConflictManager.rules.filter { $0.gesture == .threeFingerTap }
        XCTAssertEqual(rules.count, 2)
        XCTAssertTrue(rules.allSatisfy { $0.defaultsKey == "TrackpadThreeFingerTapGesture" })
    }

    func testActionRunnerShellSuccess() async {
        let runner = ActionRunner()
        let result = await runner.run(action: ActionSpec(
            kind: .shell,
            payload: "echo hello",
            timeoutMs: 1_000,
            debounceMs: 0,
            notifyOnFailure: false
        ))

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdoutTail, "hello")
    }

    func testActionRunnerShellTimeout() async {
        let runner = ActionRunner()
        let result = await runner.run(action: ActionSpec(
            kind: .shell,
            payload: "sleep 2",
            timeoutMs: 100,
            debounceMs: 0,
            notifyOnFailure: false
        ))

        XCTAssertFalse(result.succeeded)
        XCTAssertNotNil(result.errorDescription)
    }

    func testQuartzMouseLocationFlipsYCoordinate() {
        let location = ActionRunner.quartzMouseLocation(
            from: CGPoint(x: 240, y: 180),
            desktopMaxY: 1000
        )

        XCTAssertEqual(location.x, 240)
        XCTAssertEqual(location.y, 820)
    }

    private func makeFrame(timestamp: TimeInterval, contacts: [TouchContact]) -> TouchFrame {
        TouchFrame(deviceID: "device", timestamp: timestamp, contacts: contacts)
    }
}
