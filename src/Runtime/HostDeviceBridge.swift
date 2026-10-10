import Foundation
import UIKit

/// Host-side device services available to an eventual guest transport adapter.
///
/// This deliberately separates device access from the CPU emulator. It is safe
/// to use from the iOS app now, but a guest cannot call these methods until a
/// real VM network/virtio-serial adapter is connected to this service.
final class HostDeviceBridge {
    static let shared = HostDeviceBridge()
    private init() {}

    enum BridgeError: LocalizedError {
        case invalidPath
        case outsideSharedDirectory
        case unavailableDeviceInformation

        var errorDescription: String? {
            switch self {
            case .invalidPath: return "The requested host path is invalid."
            case .outsideSharedDirectory: return "The requested file is outside the i-Steam shared directory."
            case .unavailableDeviceInformation: return "Host device information is unavailable."
            }
        }
    }

    /// A user-visible shared directory that can be exposed to the guest through
    /// a future virtio-fs, 9p, or explicit file-transfer adapter.
    var sharedDirectoryURL: URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GuestShared", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    struct DeviceInfo: Codable {
        let systemName: String
        let systemVersion: String
        let model: String
        let machineIdentifier: String
        let lowPowerModeEnabled: Bool
    }

    func deviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        return DeviceInfo(
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            model: device.model,
            machineIdentifier: Self.machineIdentifier(),
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    /// Copies a guest-exported file into the host's i-Steam shared directory.
    /// The relative path is validated to prevent directory traversal.
    @discardableResult
    func receiveFile(from source: URL, relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains("\\"),
              !relativePath.split(separator: "/", omittingEmptySubsequences: false)
                .contains(where: { $0 == "." || $0 == ".." }) else {
            throw BridgeError.invalidPath
        }

        let destination = sharedDirectoryURL.appendingPathComponent(relativePath)
            .standardizedFileURL
        let root = sharedDirectoryURL.standardizedFileURL.path + "/"
        guard destination.path.hasPrefix(root) else {
            throw BridgeError.outsideSharedDirectory
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    func readSharedFile(relativePath: String) throws -> Data {
        let url = try sharedFileURL(relativePath: relativePath)
        return try Data(contentsOf: url)
    }

    func writeSharedFile(_ data: Data, relativePath: String) throws {
        let url = try sharedFileURL(relativePath: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private func sharedFileURL(relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains("\\"),
              !relativePath.split(separator: "/", omittingEmptySubsequences: false)
                .contains(where: { $0 == "." || $0 == ".." }) else {
            throw BridgeError.invalidPath
        }
        let url = sharedDirectoryURL.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(sharedDirectoryURL.standardizedFileURL.path + "/") else {
            throw BridgeError.outsideSharedDirectory
        }
        return url
    }

    private static func machineIdentifier() -> String {
        // UIDevice has no public hardware identifier. Report the model family
        // rather than reading private sysctl values or a serial number.
        return UIDevice.current.model
    }
}
