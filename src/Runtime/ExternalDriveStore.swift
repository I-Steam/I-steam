import Foundation
import UniformTypeIdentifiers

/// Manages Files.app / external-provider URLs using iOS security-scoped access.
/// iOS does not expose arbitrary USB media as raw block devices; providers grant
/// file-level access to the selected document or folder.
final class ExternalDriveStore {
    static let shared = ExternalDriveStore()
    private init() {}

    private let bookmarkKey = "iSteam.externalDrive.bookmark"
    private let nameKey = "iSteam.externalDrive.name"

    /// Persist a bookmark while the provider URL is actively accessible.
    func remember(_ url: URL) throws {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }

        let bookmark = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
    }

    /// Resolves the saved bookmark. The returned URL must be used inside
    /// withAccess(to:) so its security scope is active for the whole operation.
    func rememberedURL() throws -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale { try remember(url) }
        return url
    }

    var rememberedName: String? {
        UserDefaults.standard.string(forKey: nameKey)
    }

    /// Keeps security-scoped access active for the complete synchronous
    /// operation. NSFileCoordinator handles providers that need coordination.
    func withAccess<T>(to url: URL, _ operation: (URL) throws -> T) throws -> T {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }

        var coordinationError: NSError?
        var operationError: Error?
        var result: T?
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do { result = try operation(coordinatedURL) }
            catch { operationError = error }
        }
        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return result
    }

    func readDocument(at url: URL) throws -> Data {
        try withAccess(to: url) { coordinatedURL in
            try Data(contentsOf: coordinatedURL, options: [.mappedIfSafe])
        }
    }

    /// Copies provider-owned content into the app sandbox so later VM sessions
    /// do not depend on the Files provider remaining mounted or available.
    func copyDocument(at source: URL, to destination: URL) throws {
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }

        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: source,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                let fm = FileManager.default
                try fm.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.copyItem(at: coordinatedURL, to: destination)
            } catch { copyError = error }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }
}
