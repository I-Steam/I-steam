import Foundation
import UniformTypeIdentifiers

/// Accesses files supplied by Files.app, including USB/SD drives connected to
/// the iPhone/iPad. iOS only exposes external volumes through a document
/// provider; apps cannot mount or enumerate arbitrary USB block devices.
final class ExternalDriveStore {
    static let shared = ExternalDriveStore()
    private init() {}

    private let bookmarkKey = "iSteam.externalDrive.bookmark"

    func remember(_ url: URL) throws {
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: "iSteam.externalDrive.name")
    }

    func rememberedURL() throws -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale { try remember(url) }
        return url
    }

    /// Reads the selected document while its provider grants access. The caller
    /// can use this for import or for streaming chunks into guest disk storage.
    func readDocument(at url: URL) throws -> Data {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        var readError: Error?
        var result: Data?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { coordinatedURL in
            do { result = try Data(contentsOf: coordinatedURL, options: [.mappedIfSafe]) }
            catch { readError = error }
        }
        if let readError { throw readError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return result
    }

    func copyDocument(at source: URL, to destination: URL) throws {
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: source, options: [], error: &coordinationError) { coordinatedURL in
            do {
                let fm = FileManager.default
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
                try fm.copyItem(at: coordinatedURL, to: destination)
            } catch { copyError = error }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }
}
