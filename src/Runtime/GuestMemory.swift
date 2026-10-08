import Foundation

final class GuestMemory {
    let size: UInt64
    private var storage: Data

    init(size: UInt64) {
        self.size = size
        self.storage = Data(count: Int(min(size, UInt64(Int.max))))
    }

    func read(offset: UInt64, length: Int) -> Data? {
        guard offset < size, length >= 0, offset + UInt64(length) <= size else { return nil }
        return storage.subdata(in: Int(offset)..<Int(offset) + length)
    }

    func write(_ data: Data, offset: UInt64) -> Bool {
        guard offset < size, offset + UInt64(data.count) <= size else { return false }
        storage.replaceSubrange(Int(offset)..<Int(offset) + data.count, with: data)
        return true
    }
}
