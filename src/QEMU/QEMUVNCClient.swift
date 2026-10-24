import Foundation
import Network

/// Minimal RFB 3.8 client for the loopback-only QEMU VNC server.
/// This provides real guest pixels without requiring UTM's full SPICE renderer.
/// It deliberately supports raw framebuffer rectangles only.
final class QEMUVNCClient {
    enum ClientError: LocalizedError {
        case connection(String)
        case protocolError(String)
        var errorDescription: String? {
            switch self {
            case .connection(let message), .protocolError(let message): return message
            }
        }
    }

    private let queue = DispatchQueue(label: "com.xthrx.isteam.qemu-vnc")
    private let lock = NSLock()
    private var connection: NWConnection?
    private var readerTask: Task<Void, Never>?
    private var framebuffer = Data()
    private var framebufferWidth = 0
    private var framebufferHeight = 0
    private var pointerX: Int = 0
    private var pointerY: Int = 0
    private var pressedKeys = Set<UInt32>()
    private(set) var isConnected = false
    var onFrame: ((Data, Int, Int) -> Void)?
    var onStatus: ((String) -> Void)?

    func start(port: UInt16 = 5900) {
        stop()
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            onStatus?("Invalid local VNC port.")
            return
        }
        readerTask = Task { [weak self] in
            guard let self else { return }
            var lastError: Error = ClientError.connection("QEMU VNC server did not start.")
            for attempt in 0..<40 {
                if Task.isCancelled { return }
                let candidate = NWConnection(host: "127.0.0.1", port: endpointPort, using: .tcp)
                self.lock.lock()
                self.connection = candidate
                self.lock.unlock()
                do {
                    try await self.waitUntilReady(candidate)
                    try await self.performHandshake(candidate)
                    self.lock.lock()
                    self.isConnected = true
                    self.lock.unlock()
                    self.onStatus?("Guest display connected • local VNC")
                    try await self.readServerMessages(candidate)
                    break
                } catch {
                    lastError = error
                    candidate.cancel()
                    if Task.isCancelled { return }
                    if attempt < 39 {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
            self.lock.lock()
            self.isConnected = false
            self.lock.unlock()
            self.onStatus?("Guest display unavailable: \(lastError.localizedDescription)")
        }
    }

    func stop() {
        readerTask?.cancel()
        readerTask = nil
        connection?.cancel()
        connection = nil
        lock.lock()
        isConnected = false
        pressedKeys.removeAll()
        lock.unlock()
    }

    private func waitUntilReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var completed = false
            connection.stateUpdateHandler = { state in
                guard !completed else { return }
                switch state {
                case .ready:
                    completed = true
                    continuation.resume()
                case .failed(let error):
                    completed = true
                    continuation.resume(throwing: ClientError.connection(error.localizedDescription))
                case .cancelled:
                    completed = true
                    continuation.resume(throwing: ClientError.connection("The local QEMU display connection was cancelled."))
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
    }

    private func receiveExactly(_ count: Int, from connection: NWConnection) async throws -> Data {
        guard count >= 0, count <= 64 * 1024 * 1024 else {
            throw ClientError.protocolError("QEMU sent an invalid framebuffer length.")
        }
        var result = Data()
        result.reserveCapacity(count)
        while result.count < count {
            if Task.isCancelled { throw CancellationError() }
            let remaining = count - result.count
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: remaining) { data, _, complete, error in
                    if let error {
                        continuation.resume(throwing: ClientError.connection(error.localizedDescription))
                    } else if let data, !data.isEmpty {
                        continuation.resume(returning: data)
                    } else if complete {
                        continuation.resume(throwing: ClientError.connection("QEMU closed the guest display connection."))
                    } else {
                        continuation.resume(throwing: ClientError.connection("The guest display returned no data."))
                    }
                }
            }
            result.append(chunk)
        }
        return result
    }

    private func send(_ data: Data, to connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: ClientError.connection(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func performHandshake(_ connection: NWConnection) async throws {
        let serverVersion = try await receiveExactly(12, from: connection)
        guard let version = String(data: serverVersion, encoding: .ascii),
              version.hasPrefix("RFB 003.") else {
            throw ClientError.protocolError("QEMU did not offer a supported RFB/VNC protocol.")
        }
        try await send(Data("RFB 003.008\n".utf8), to: connection)

        let countData = try await receiveExactly(1, from: connection)
        let count = Int(countData[0])
        guard count > 0 else {
            throw ClientError.protocolError("QEMU VNC offered no authentication methods.")
        }
        let methods = try await receiveExactly(count, from: connection)
        guard methods.contains(1) else {
            throw ClientError.protocolError("QEMU VNC must be configured for no-authentication on loopback only.")
        }
        try await send(Data([1]), to: connection)
        let securityResult = try await receiveExactly(4, from: connection)
        guard securityResult.allSatisfy({ $0 == 0 }) else {
            throw ClientError.protocolError("QEMU rejected the local VNC handshake.")
        }
        try await send(Data([1]), to: connection) // ClientInit: shared session.

        let serverInit = try await receiveExactly(24, from: connection)
        let width = Int(Self.u16(serverInit, 0))
        let height = Int(Self.u16(serverInit, 2))
        let nameLength = Int(Self.u32(serverInit, 20))
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              width <= Int.max / height / 4, nameLength <= 1_048_576 else {
            throw ClientError.protocolError("QEMU announced an unsupported guest display size.")
        }
        _ = try await receiveExactly(nameLength, from: connection)
        framebufferWidth = width
        framebufferHeight = height
        framebuffer = Data(repeating: 0, count: width * height * 4)
        pointerX = width / 2
        pointerY = height / 2

        // 32bpp, 24-bit depth, little endian, true colour; memory order B,G,R,X.
        try await send(Data([0, 0, 0, 0, 32, 24, 0, 1,
                             0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0]), to: connection)
        // Raw rectangles and DesktopSize updates only.
        try await send(Data([2, 0, 0, 2,
                             0, 0, 0, 0,
                             0xff, 0xff, 0xff, 0x21]), to: connection)
        try await requestFramebufferUpdate(incremental: false, connection: connection)
    }

    private func readServerMessages(_ connection: NWConnection) async throws {
        while !Task.isCancelled {
            let type = try await receiveExactly(1, from: connection)[0]
            switch type {
            case 0: // FramebufferUpdate
                _ = try await receiveExactly(1, from: connection) // padding
                let count = Int(Self.u16(try await receiveExactly(2, from: connection), 0))
                for _ in 0..<count {
                    let header = try await receiveExactly(12, from: connection)
                    let x = Int(Self.u16(header, 0))
                    let y = Int(Self.u16(header, 2))
                    let width = Int(Self.u16(header, 4))
                    let height = Int(Self.u16(header, 6))
                    let encoding = Int32(bitPattern: Self.u32(header, 8))
                    if encoding == -223 { // DesktopSize
                        guard width > 0, height > 0, width <= 8192, height <= 8192,
                              width <= Int.max / height / 4 else {
                            throw ClientError.protocolError("QEMU requested an invalid guest display size.")
                        }
                        framebufferWidth = width
                        framebufferHeight = height
                        framebuffer = Data(repeating: 0, count: width * height * 4)
                        pointerX = min(pointerX, width - 1)
                        pointerY = min(pointerY, height - 1)
                        continue
                    }
                    guard encoding == 0 else {
                        throw ClientError.protocolError("Unsupported QEMU VNC rectangle encoding \(encoding).")
                    }
                    guard width > 0, height > 0, x + width <= framebufferWidth,
                          y + height <= framebufferHeight, width <= Int.max / height / 4 else {
                        throw ClientError.protocolError("QEMU sent a framebuffer rectangle outside the guest display.")
                    }
                    let pixels = try await receiveExactly(width * height * 4, from: connection)
                    for row in 0..<height {
                        let sourceStart = row * width * 4
                        let destinationStart = ((y + row) * framebufferWidth + x) * 4
                        framebuffer.replaceSubrange(destinationStart..<(destinationStart + width * 4),
                                                    with: pixels[sourceStart..<(sourceStart + width * 4)])
                    }
                }
                onFrame?(framebuffer, framebufferWidth, framebufferHeight)
                try await requestFramebufferUpdate(incremental: true, connection: connection)
            case 1: // SetColourMapEntries: padding + first-colour + colour-count.
                let header = try await receiveExactly(5, from: connection)
                let numberOfColours = Int(Self.u16(header, 3))
                _ = try await receiveExactly(numberOfColours * 6, from: connection)
            case 2: // Bell
                break
            case 3: // ServerCutText
                _ = try await receiveExactly(3, from: connection)
                let length = Int(Self.u32(try await receiveExactly(4, from: connection), 0))
                guard length <= 1_048_576 else { throw ClientError.protocolError("Clipboard payload too large.") }
                _ = try await receiveExactly(length, from: connection)
            default:
                throw ClientError.protocolError("Unknown QEMU VNC server message type \(type).")
            }
        }
    }

    private func requestFramebufferUpdate(incremental: Bool, connection: NWConnection) async throws {
        try await send(Data([3, incremental ? 1 : 0, 0, 0,
                             UInt8((framebufferWidth >> 8) & 0xff), UInt8(framebufferWidth & 0xff),
                             UInt8((framebufferHeight >> 8) & 0xff), UInt8(framebufferHeight & 0xff)]),
                       to: connection)
    }

    func sendKey(_ key: String, down: Bool) {
        guard let connection else { return }
        guard let keysym = Self.keysym(for: key) else { return }
        let value = UInt32(keysym)
        let message = Data([4, down ? 1 : 0, 0, 0,
                            UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
                            UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
        Task { try? await self.send(message, to: connection) }
    }

    func tapKey(_ key: String) {
        guard let connection, let keysym = Self.keysym(for: key) else { return }
        let value = UInt32(keysym)
        let press = Data([4, 1, 0, 0, UInt8((value >> 24) & 0xff),
                          UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
        let release = Data([4, 0, 0, 0, UInt8((value >> 24) & 0xff),
                            UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
        Task {
            try? await self.send(press, to: connection)
            try? await self.send(release, to: connection)
        }
    }

    func setMovement(x: Float, y: Float) {
        let desired = Set([
            abs(x) > 0.25 ? (x < 0 ? "A" : "D") : "",
            abs(y) > 0.25 ? (y < 0 ? "W" : "S") : ""
        ].filter { !$0.isEmpty })
        lock.lock()
        let previous = pressedKeys
        let next = Set(desired.compactMap { Self.keysym(for: $0) })
        pressedKeys = next
        lock.unlock()
        for key in previous.subtracting(next) { sendKeysym(key, down: false) }
        for key in next.subtracting(previous) { sendKeysym(key, down: true) }
    }

    func movePointer(dx: Float, dy: Float) {
        guard let connection, framebufferWidth > 0, framebufferHeight > 0 else { return }
        pointerX = min(max(pointerX + Int(dx * 12), 0), framebufferWidth - 1)
        pointerY = min(max(pointerY - Int(dy * 12), 0), framebufferHeight - 1)
        let x = pointerX, y = pointerY
        let message = Data([5, 0, UInt8((x >> 8) & 0xff), UInt8(x & 0xff),
                            UInt8((y >> 8) & 0xff), UInt8(y & 0xff)])
        Task { try? await self.send(message, to: connection) }
    }

    func sendButton(_ name: String, down: Bool) {
        let key: String
        switch name {
        case "A": key = "SPACE"
        case "B": key = "ESC"
        case "X": key = "E"
        case "Y": key = "Q"
        case "Start", "Menu": key = "ENTER"
        case "LB", "L1": key = "TAB"
        case "RB", "R1": key = "R"
        case "DPadUp": key = "UP"
        case "DPadDown": key = "DOWN"
        case "DPadLeft": key = "LEFT"
        case "DPadRight": key = "RIGHT"
        default: return
        }
        sendKey(key, down: down)
    }

    private func sendKeysym(_ keysym: UInt32, down: Bool) {
        let value = keysym
        let message = Data([4, down ? 1 : 0, 0, 0,
                            UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
                            UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
        guard let connection else { return }
        Task { try? await self.send(message, to: connection) }
    }

    private static func keysym(for key: String) -> UInt32? {
        let value = key.uppercased()
        switch value {
        case "ESC", "ESCAPE": return 0xff1b
        case "ENTER", "RETURN": return 0xff0d
        case "TAB": return 0xff09
        case "BACKSPACE", "⌫": return 0xff08
        case "SPACE": return 0x20
        case "SHIFT": return 0xffe1
        case "CTRL": return 0xffe3
        case "ALT": return 0xffe9
        case "UP", "↑": return 0xff52
        case "DOWN", "↓": return 0xff54
        case "LEFT", "←": return 0xff51
        case "RIGHT", "→": return 0xff53
        case "F1": return 0xffbe
        case "F2": return 0xffbf
        case "F3": return 0xffc0
        case "F4": return 0xffc1
        case "F5": return 0xffc2
        case "F6": return 0xffc3
        case "F7": return 0xffc4
        case "F8": return 0xffc5
        case "F9": return 0xffc6
        case "F10": return 0xffc7
        case "F11": return 0xffc8
        case "F12": return 0xffc9
        default:
            guard value.count == 1, let scalar = value.unicodeScalars.first,
                  scalar.value < 128 else { return nil }
            return scalar.value
        }
    }

    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24) | (UInt32(data[offset + 1]) << 16) |
        (UInt32(data[offset + 2]) << 8) | UInt32(data[offset + 3])
    }
}
