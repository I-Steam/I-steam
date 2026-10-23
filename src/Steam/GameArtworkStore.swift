import Foundation
import ImageIO

/// App-sandboxed cover-art cache. Artwork is copied from user-selected URLs;
/// remote URLs are not fetched implicitly and the original source is never modified.
final class GameArtworkStore {
    static let shared = GameArtworkStore()
    private let fm = FileManager.default
    private let maxBytes = 12 * 1024 * 1024
    private init() {}

    private var directory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("GameArtwork", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @discardableResult
    func importArtwork(from source: URL, for gameID: UUID) throws -> URL {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let values = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= maxBytes else {
            throw ArtworkError.invalidFile
        }
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var imageData: Data?
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { readableURL in
            imageData = try? Data(contentsOf: readableURL, options: [.mappedIfSafe])
        }
        if let coordinationError { throw coordinationError }
        guard let data = imageData, data.count <= maxBytes,
              let image = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(image) > 0,
              let type = CGImageSourceGetType(image) as String?,
              ["public.jpeg", "public.png", "public.heic", "public.webp", "com.compuserve.gif"].contains(type) else {
            throw ArtworkError.invalidImage
        }
        let ext: String
        switch type {
        case "public.jpeg": ext = "jpg"
        case "public.png": ext = "png"
        case "public.heic": ext = "heic"
        case "public.webp": ext = "webp"
        default: ext = "gif"
        }
        let destination = directory.appendingPathComponent(gameID.uuidString).appendingPathExtension(ext)
        try data.write(to: destination, options: .atomic)
        EmulationLog.shared.write("Cached cover artwork for game \(gameID.uuidString)")
        return destination
    }

    func artworkURL(for gameID: UUID) -> URL? {
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }
        return files.first { $0.deletingPathExtension().lastPathComponent == gameID.uuidString }
    }

    func removeArtwork(for gameID: UUID) throws {
        guard let url = artworkURL(for: gameID) else { return }
        try fm.removeItem(at: url)
    }

    enum ArtworkError: LocalizedError {
        case invalidFile, invalidImage
        var errorDescription: String? {
            switch self {
            case .invalidFile: return "Artwork must be a regular file no larger than 12 MB."
            case .invalidImage: return "The selected file is not a supported, readable image."
            }
        }
    }
}
