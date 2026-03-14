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

    func testConfigStoreRoundTrip() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ConfigStore(baseDirectoryURL: tempDirectory)
        let original = AppConfig.default

        try store.save(original)
        let loaded = try store.load()

        XCTAssertEqual(loaded, original)
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

    private func makeFrame(timestamp: TimeInterval, contacts: [TouchContact]) -> TouchFrame {
        TouchFrame(deviceID: "device", timestamp: timestamp, contacts: contacts)
    }
}
