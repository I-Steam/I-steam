import Foundation

/// Sparse, bounds-checked guest physical memory.
final class GuestMemory {
    static let pageSize: UInt64 = 4096

    let size: UInt64
    private var pages: [UInt64: Data] = [:]
    private let lock = NSLock()

    init(size: UInt64) {
        self.size = size
    }

    /// Reads bytes from guest physical memory. Unallocated pages read as zero.
    func read(offset: UInt64, length: Int) -> Data? {
        guard length >= 0, offset <= size else { return nil }
        let byteCount = UInt64(length)
        guard byteCount <= size - offset else { return nil }
        if length == 0 { return Data() }

        var result = Data(count: length)
        lock.lock()
        defer { lock.unlock() }

        var guestOffset = offset
        var resultOffset = 0
        while resultOffset < length {
            let pageIndex = guestOffset / Self.pageSize
            let pageOffset = Int(guestOffset % Self.pageSize)
            let amount = min(length - resultOffset, Int(Self.pageSize) - pageOffset)
            if let page = pages[pageIndex] {
                result.replaceSubrange(resultOffset..<(resultOffset + amount),
                                       with: page[pageOffset..<(pageOffset + amount)])
            }
            guestOffset += UInt64(amount)
            resultOffset += amount
        }
        return result
    }

    /// Writes only after validating that the whole range fits.
    @discardableResult
    func write(_ data: Data, offset: UInt64) -> Bool {
        guard offset <= size else { return false }
        let byteCount = UInt64(data.count)
        guard byteCount <= size - offset else { return false }
        if data.isEmpty { return true }

        lock.lock()
        defer { lock.unlock() }
        var guestOffset = offset
        var sourceOffset = 0
        while sourceOffset < data.count {
            let pageIndex = guestOffset / Self.pageSize
            let pageOffset = Int(guestOffset % Self.pageSize)
            let amount = min(data.count - sourceOffset, Int(Self.pageSize) - pageOffset)
            var page = pages[pageIndex] ?? Data(count: Int(Self.pageSize))
            page.replaceSubrange(pageOffset..<(pageOffset + amount),
                                 with: data[sourceOffset..<(sourceOffset + amount)])
            pages[pageIndex] = page
            guestOffset += UInt64(amount)
            sourceOffset += amount
        }
        return true
    }

    /// Zeroes a range without allocating a buffer proportional to its size.
    /// Missing pages already read as zero, so they remain unallocated.
    @discardableResult
    func zero(offset: UInt64, length: UInt64) -> Bool {
        guard offset <= size, length <= size - offset else { return false }
        if length == 0 { return true }

        lock.lock()
        defer { lock.unlock() }
        var guestOffset = offset
        let end = offset + length
        while guestOffset < end {
            let pageIndex = guestOffset / Self.pageSize
            let pageOffset = Int(guestOffset % Self.pageSize)
            let amount = Int(min(end - guestOffset, Self.pageSize - UInt64(pageOffset)))
            if var page = pages[pageIndex] {
                page.replaceSubrange(pageOffset..<(pageOffset + amount),
                                     with: repeatElement(UInt8(0), count: amount))
                pages[pageIndex] = page
            }
            guestOffset += UInt64(amount)
        }
        return true
    }

    func clear() {
        lock.lock()
        pages.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    var allocatedPageCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pages.count
    }
}
