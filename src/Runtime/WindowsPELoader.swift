import Foundation

/// Performs bounded, read-only inspection of a Windows PE image.
/// This does not map sections, resolve imports, or execute code.
final class WindowsPELoader {
    struct Image {
        let url: URL
        let isPE: Bool
        let machine: UInt16
        let subsystem: UInt16?
        let is64Bit: Bool
        let sectionCount: UInt16
        let optionalHeaderSize: UInt16
        let fileSize: UInt64
    }

    enum InspectionError: LocalizedError {
        case unreadableFile, tooSmall, invalidDOSHeader, invalidPEOffset
        case invalidSignature, truncatedCOFFHeader, invalidOptionalHeader
        case unsupportedOptionalHeader

        var errorDescription: String? {
            switch self {
            case .unreadableFile: return "The executable could not be read."
            case .tooSmall: return "The file is too small to contain a Windows PE header."
            case .invalidDOSHeader: return "The file does not have a valid MZ/DOS header."
            case .invalidPEOffset: return "The PE header offset is outside the file or overflows."
            case .invalidSignature: return "The PE signature is missing or invalid."
            case .truncatedCOFFHeader: return "The PE COFF header is truncated."
            case .invalidOptionalHeader: return "The PE optional header is truncated or inconsistent."
            case .unsupportedOptionalHeader: return "The PE optional-header magic is not PE32 or PE32+."
            }
        }
    }

    func load(_ url: URL) throws -> Image {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw InspectionError.unreadableFile
        }

        guard data.count >= 0x40 else { throw InspectionError.tooSmall }
        guard data[0] == 0x4D, data[1] == 0x5A else {
            throw InspectionError.invalidDOSHeader
        }

        guard let peOffset32 = readUInt32LE(data, at: 0x3C) else {
            throw InspectionError.invalidDOSHeader
        }
        let peOffset = UInt64(peOffset32)
        let fileSize = UInt64(data.count)
        guard peOffset >= 0x40, peOffset <= fileSize,
              fileSize - peOffset >= 24 else {
            throw InspectionError.invalidPEOffset
        }

        let signatureOffset = Int(peOffset)
        guard data[signatureOffset] == 0x50,
              data[signatureOffset + 1] == 0x45,
              data[signatureOffset + 2] == 0,
              data[signatureOffset + 3] == 0 else {
            throw InspectionError.invalidSignature
        }

        let coffOffset = signatureOffset + 4
        guard let machine = readUInt16LE(data, at: coffOffset),
              let sectionCount = readUInt16LE(data, at: coffOffset + 2),
              let optionalHeaderSize = readUInt16LE(data, at: coffOffset + 16) else {
            throw InspectionError.truncatedCOFFHeader
        }

        let optionalOffset = coffOffset + 20
        let optionalSize = Int(optionalHeaderSize)
        guard optionalOffset <= data.count,
              optionalSize <= data.count - optionalOffset else {
            throw InspectionError.invalidOptionalHeader
        }

        var subsystem: UInt16?
        var is64Bit = false
        if optionalSize > 0 {
            guard optionalSize >= 2,
                  let magic = readUInt16LE(data, at: optionalOffset) else {
                throw InspectionError.invalidOptionalHeader
            }
            switch magic {
            case 0x10B: is64Bit = false
            case 0x20B: is64Bit = true
            default: throw InspectionError.unsupportedOptionalHeader
            }
            if optionalSize >= 70 {
                subsystem = readUInt16LE(data, at: optionalOffset + 68)
            }
        }

        return Image(
            url: url,
            isPE: true,
            machine: machine,
            subsystem: subsystem,
            is64Bit: is64Bit,
            sectionCount: sectionCount,
            optionalHeaderSize: optionalHeaderSize,
            fileSize: fileSize
        )
    }

    private func readUInt16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= data.count, data.count - offset >= 2 else {
            return nil
        }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= data.count, data.count - offset >= 4 else {
            return nil
        }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
