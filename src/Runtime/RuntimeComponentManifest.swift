import Foundation
import CryptoKit

/// Describes a runtime artifact that has already been obtained through a trusted
/// distribution channel. This service verifies local files; it does not download,
/// install, or execute binaries.
struct RuntimeComponentManifest: Codable, Equatable {
    struct Component: Codable, Equatable, Identifiable {
        let id: String
        let version: String
        let relativePath: String
        let sha256: String
        let platforms: [String]
        let license: String
        var identifier: String { id }
        var isValidIdentifier: Bool {
            !id.isEmpty && id.count <= 96 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
        }
    }

    let schemaVersion: Int
    let generatedAt: Date
    let components: [Component]
}

/// Local manifest parser and integrity verifier for runtime/driver bundles.
/// Paths are constrained to the selected root and SHA-256 values must match.
enum RuntimeComponentVerifier {
    enum Verification: Equatable {
        case valid(componentID: String, version: String)
        case missing(componentID: String)
        case unsafePath(componentID: String)
        case checksumMismatch(componentID: String)
        case unsupportedPlatform(componentID: String)
    }

    static func decodeManifest(_ data: Data) throws -> RuntimeComponentManifest {
        guard data.count <= 2 * 1024 * 1024 else { throw Error.manifestTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(RuntimeComponentManifest.self, from: data)
        guard manifest.schemaVersion == 1, manifest.components.count <= 2_000 else {
            throw Error.unsupportedManifest
        }
        var seen = Set<String>()
        for item in manifest.components {
            guard item.isValidIdentifier, !item.version.isEmpty, item.version.count <= 64,
                  item.sha256.count == 64, item.sha256.allSatisfy({ $0.isHexDigit }),
                  !item.license.isEmpty, seen.insert(item.id).inserted else {
                throw Error.invalidComponent
            }
        }
        return manifest
    }

    static func verify(_ component: RuntimeComponentManifest.Component,
                       under root: URL,
                       platform: String) -> Verification {
        guard component.platforms.contains(platform) else { return .unsupportedPlatform(componentID: component.id) }
        let relative = component.relativePath
        guard !relative.isEmpty, !relative.hasPrefix("/"),
              !relative.split(separator: "/").contains(".."),
              !relative.contains("\\") else { return .unsafePath(componentID: component.id) }
        let standardizedRoot = root.standardizedFileURL
        let candidate = root.appendingPathComponent(relative).standardizedFileURL
        guard candidate.path.hasPrefix(standardizedRoot.path + "/") else { return .unsafePath(componentID: component.id) }
        guard let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey]),
              values.isRegularFile == true, let stream = InputStream(url: candidate) else {
            return .missing(componentID: component.id)
        }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { return .missing(componentID: component.id) }
            if count == 0 { break }
            hasher.update(data: Data(buffer[0..<count]))
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(component.sha256) == .orderedSame else {
            return .checksumMismatch(componentID: component.id)
        }
        return .valid(componentID: component.id, version: component.version)
    }

    enum Error: LocalizedError {
        case manifestTooLarge, unsupportedManifest, invalidComponent
        var errorDescription: String? {
            switch self {
            case .manifestTooLarge: return "The runtime manifest exceeds the 2 MB limit."
            case .unsupportedManifest: return "The runtime manifest version or component count is unsupported."
            case .invalidComponent: return "The runtime manifest contains an invalid or duplicate component."
            }
        }
    }
}
