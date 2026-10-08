import Foundation

final class WindowsPELoader {
    struct Image {
        let url: URL
        let isPE: Bool
        let machine: UInt16?
        let subsystem: UInt16?
    }

    func load(_ url: URL) throws -> Image {
        let data = try Data(contentsOf: url)
        guard data.count >= 0x40, data[0] == 0x4D, data[1] == 0x5A else {
            throw NSError(domain: "iSteam.PE", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a Windows PE executable"])
        }

        let peOffset = Int(UInt32(data[0x3C]) | UInt32(data[0x3D]) << 8 | UInt32(data[0x3E]) << 16 | UInt32(data[0x3F]) << 24)
        guard peOffset + 6 < data.count, data[peOffset] == 0x50, data[peOffset + 1] == 0x45, data[peOffset + 2] == 0, data[peOffset + 3] == 0 else {
            throw NSError(domain: "iSteam.PE", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid PE header"])
        }

        let machine = UInt16(data[peOffset + 4]) | UInt16(data[peOffset + 5]) << 8
        let optionalOffset = peOffset + 24
        let subsystem = optionalOffset + 70 < data.count ? UInt16(data[optionalOffset + 68]) | UInt16(data[optionalOffset + 69]) << 8 : nil
        return Image(url: url, isPE: true, machine: machine, subsystem: subsystem)
    }
}
