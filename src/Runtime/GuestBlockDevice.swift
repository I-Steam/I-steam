import Foundation

/// Host-side random-access disk-image storage. Uses bounded sector reads/writes;
/// this is not yet attached to a guest-visible SATA or virtio controller.
final class GuestBlockDevice {
    enum DeviceError: LocalizedError {
        case invalidGeometry, outOfBounds, readOnly, shortRead
        var errorDescription: String? {
            switch self {
            case .invalidGeometry: return "Invalid disk image geometry."
            case .outOfBounds: return "Disk request is outside the image."
            case .readOnly: return "Disk image is read-only."
            case .shortRead: return "Disk image returned fewer bytes than requested."
            }
        }
    }

    static let defaultSectorSize: UInt64 = 512
    let url: URL
    let sectorSize: UInt64
    let sectorCount: UInt64
    let readOnly: Bool
    private let handle: FileHandle
    private let lock = NSLock()

    init(url: URL, sectorSize: UInt64 = GuestBlockDevice.defaultSectorSize, readOnly: Bool = false) throws {
        guard sectorSize > 0, sectorSize <= 65_536 else { throw DeviceError.invalidGeometry }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size >= 0 else {
            throw DeviceError.invalidGeometry
        }
        self.url = url
        self.sectorSize = sectorSize
        self.sectorCount = UInt64(size) / sectorSize
        self.readOnly = readOnly
        self.handle = try readOnly ? FileHandle(forReadingFrom: url) : FileHandle(forUpdating: url)
    }

    deinit { try? handle.close() }
    var capacityBytes: UInt64 { sectorCount * sectorSize }

    func read(lba: UInt64, count: UInt32 = 1) throws -> Data {
        guard lba <= sectorCount, UInt64(count) <= sectorCount - lba else { throw DeviceError.outOfBounds }
        let byteCount = UInt64(count) * sectorSize
        guard byteCount <= UInt64(Int.max) else { throw DeviceError.invalidGeometry }
        lock.lock()
        defer { lock.unlock() }
        try handle.seek(toOffset: lba * sectorSize)
        let data = try handle.read(upToCount: Int(byteCount)) ?? Data()
        guard data.count == Int(byteCount) else { throw DeviceError.shortRead }
        return data
    }

    func write(_ data: Data, lba: UInt64) throws {
        guard !readOnly else { throw DeviceError.readOnly }
        guard data.count % Int(sectorSize) == 0 else { throw DeviceError.invalidGeometry }
        let count = UInt64(data.count) / sectorSize
        guard lba <= sectorCount, count <= sectorCount - lba else { throw DeviceError.outOfBounds }
        lock.lock()
        defer { lock.unlock() }
        try handle.seek(toOffset: lba * sectorSize)
        try handle.write(contentsOf: data)
    }

    func synchronize() throws {
        lock.lock()
        defer { lock.unlock() }
        try handle.synchronize()
    }
}
