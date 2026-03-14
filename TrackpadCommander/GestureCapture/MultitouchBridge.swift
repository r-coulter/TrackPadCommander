import Foundation

final class MultitouchBridge {
    typealias FrameHandler = @MainActor (TouchFrame) -> Void

    private typealias MTDeviceRef = UnsafeMutableRawPointer

    private struct MTTouchData {
        var frame: Int32
        var timestamp: Double
        var identifier: Int32
        var state: Int32
        var unknown1: Int32
        var unknown2: Int32
        var normalizedPosition: SIMD2<Float>
        var size: Float
        var angle: Float
        var majorAxis: Float
        var minorAxis: Float
        var unknown3: SIMD2<Float>
        var unknown4: Int32
        var unknown5: Float
    }

    private typealias ContactFrameCallback = @convention(c) (
        MTDeviceRef?,
        UnsafeRawPointer?,
        Int32,
        Double,
        Int32
    ) -> Int32

    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>
    private typealias RegisterCallbackFn = @convention(c) (MTDeviceRef?, ContactFrameCallback) -> Void
    private typealias UnregisterCallbackFn = @convention(c) (MTDeviceRef?, ContactFrameCallback) -> Void
    private typealias DeviceStartFn = @convention(c) (MTDeviceRef?, Int32) -> Void
    private typealias DeviceStopFn = @convention(c) (MTDeviceRef?) -> Void

    nonisolated(unsafe) private static weak var shared: MultitouchBridge?

    private let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var createList: CreateListFn?
    private var registerCallback: RegisterCallbackFn?
    private var unregisterCallback: UnregisterCallbackFn?
    private var deviceStart: DeviceStartFn?
    private var deviceStop: DeviceStopFn?
    private var devices: [MTDeviceRef] = []
    private var frameHandler: FrameHandler?
    private(set) var isAvailable = false

    init() {
        Self.shared = self
        loadFramework()
    }

    deinit {
        stop()
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    func start(frameHandler: @escaping FrameHandler) {
        self.frameHandler = frameHandler
        guard isAvailable else { return }

        stop()
        devices = enumerateDevices()
        for device in devices {
            registerCallback?(device, Self.contactCallback)
            deviceStart?(device, 0)
        }
    }

    func reconnectDevices() {
        guard frameHandler != nil else { return }
        start(frameHandler: frameHandler!)
    }

    func stop() {
        guard !devices.isEmpty else { return }
        for device in devices {
            unregisterCallback?(device, Self.contactCallback)
            deviceStop?(device)
        }
        devices.removeAll()
    }

    private func loadFramework() {
        frameworkHandle = dlopen(frameworkPath, RTLD_NOW)
        guard let frameworkHandle else { return }

        func loadSymbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let symbol = dlsym(frameworkHandle, name) else { return nil }
            return unsafeBitCast(symbol, to: type)
        }

        createList = loadSymbol("MTDeviceCreateList", as: CreateListFn.self)
        registerCallback = loadSymbol("MTRegisterContactFrameCallback", as: RegisterCallbackFn.self)
        unregisterCallback = loadSymbol("MTUnregisterContactFrameCallback", as: UnregisterCallbackFn.self)
        deviceStart = loadSymbol("MTDeviceStart", as: DeviceStartFn.self)
        deviceStop = loadSymbol("MTDeviceStop", as: DeviceStopFn.self)

        isAvailable = createList != nil && registerCallback != nil && unregisterCallback != nil && deviceStart != nil && deviceStop != nil
    }

    private func enumerateDevices() -> [MTDeviceRef] {
        guard let createList else { return [] }
        let array = createList().takeUnretainedValue()
        let count = CFArrayGetCount(array)
        guard count > 0 else { return [] }

        return (0..<count).compactMap { index in
            let value = CFArrayGetValueAtIndex(array, index)
            return UnsafeMutableRawPointer(mutating: value)
        }
    }

    private func handleCallback(
        device: MTDeviceRef?,
        touches: UnsafeRawPointer?,
        count: Int32,
        timestamp: Double
    ) {
        guard let frameHandler,
              let device else { return }

        let contacts: [TouchContact]
        if let touches, count > 0 {
            let typedTouches = touches.bindMemory(to: MTTouchData.self, capacity: Int(count))
            let buffer = UnsafeBufferPointer(start: typedTouches, count: Int(count))
            contacts = buffer.map { touch in
                TouchContact(
                    identifier: Int(touch.identifier),
                    normalizedPosition: CGPoint(
                        x: CGFloat(touch.normalizedPosition.x),
                        y: CGFloat(touch.normalizedPosition.y)
                    ),
                    normalizedVelocity: .zero
                )
            }
        } else {
            contacts = []
        }

        let frame = TouchFrame(
            deviceID: String(UInt(bitPattern: device), radix: 16),
            timestamp: timestamp,
            contacts: contacts
        )

        Task { @MainActor in
            frameHandler(frame)
        }
    }

    private static let contactCallback: ContactFrameCallback = { device, touches, count, timestamp, _ in
        shared?.handleCallback(device: device, touches: touches, count: count, timestamp: timestamp)
        return 0
    }
}
