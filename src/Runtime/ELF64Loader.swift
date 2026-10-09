import Foundation

/// Minimal ELF64 little-endian loader for inspecting and placing PT_LOAD
/// segments into GuestMemory. This is not a Linux boot protocol implementation:
/// kernel setup, initrd, page tables, CPU state and device boot remain separate.
final class ELF64Loader {
    struct Segment {
        let guestAddress: UInt64
        let fileSize: UInt64
        let memorySize: UInt64
        let flags: UInt32
    }

    struct Image {
        let entryPoint: UInt64
        let machine: UInt16
        let segments: [Segment]
        let loadedByteCount: UInt64
    }

    enum LoadError: LocalizedError {
        case unreadable, invalidMagic, unsupportedClassOrEndian
        case truncatedHeader, invalidProgramHeaderTable, noLoadableSegments
        case invalidSegment, segmentOutsideGuestMemory, unsupportedMachine(UInt16)

        var errorDescription: String? {
            switch self {
            case .unreadable: return "The ELF image could not be read."
            case .invalidMagic: return "The file is not an ELF image."
            case .unsupportedClassOrEndian: return "Only little-endian ELF64 images are supported."
            case .truncatedHeader: return "The ELF64 header is truncated or invalid."
            case .invalidProgramHeaderTable: return "The ELF program-header table is outside the file."
            case .noLoadableSegments: return "The ELF image contains no loadable segments."
            case .invalidSegment: return "An ELF load segment has invalid file or memory sizes."
            case .segmentOutsideGuestMemory: return "An ELF load segment does not fit in guest memory."
            case .unsupportedMachine(let machine): return "Unsupported ELF machine type: \(machine)."
            }
        }
    }

    /// Validates every segment before changing guest memory. Zeroing all target
    /// segments before copying any file bytes avoids wiping earlier file data
    /// when valid PT_LOAD segments overlap.
    func load(_ url: URL, into memory: GuestMemory,
              expectedArchitecture: VMConfiguration.Architecture) throws -> Image {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw LoadError.unreadable
        }

        guard data.count >= 64,
              data[0] == 0x7F, data[1] == 0x45,
              data[2] == 0x4C, data[3] == 0x46 else {
            throw LoadError.invalidMagic
        }
        guard data[4] == 2, data[5] == 1 else {
            throw LoadError.unsupportedClassOrEndian
        }

        guard let machine = u16(data, 18),
              let entry = u64(data, 24),
              let phoff = u64(data, 32),
              let ehsize = u16(data, 52),
              let phentsize = u16(data, 54),
              let phnum = u16(data, 56),
              ehsize >= 64, phentsize >= 56 else {
            throw LoadError.truncatedHeader
        }

        let expectedMachine: UInt16
        switch expectedArchitecture {
        case .x86_64: expectedMachine = 62
        case .arm64: expectedMachine = 183
        case .riscv64: expectedMachine = 243
        }
        guard machine == expectedMachine else {
            throw LoadError.unsupportedMachine(machine)
        }

        // Validate before converting UInt64 to Int; a hostile ELF offset must
        // not trap during integer conversion on the host.
        guard phoff <= UInt64(data.count), phoff <= UInt64(Int.max) else {
            throw LoadError.invalidProgramHeaderTable
        }
        let tableOffset = Int(phoff)
        let entrySize = Int(phentsize)
        let entryCount = Int(phnum)
        guard entryCount == 0 ||
              entrySize <= (data.count - tableOffset) / entryCount else {
            throw LoadError.invalidProgramHeaderTable
        }

        var segments: [Segment] = []
        var pending: [(Segment, Int)] = []
        var total: UInt64 = 0

        for index in 0..<entryCount {
            let base = tableOffset + index * entrySize
            guard let type = u32(data, base),
                  let flags = u32(data, base + 4),
                  let fileOffset = u64(data, base + 8),
                  let virtualAddress = u64(data, base + 16),
                  let physicalAddress = u64(data, base + 24),
                  let fileSize = u64(data, base + 32),
                  let memorySize = u64(data, base + 40) else {
                throw LoadError.invalidProgramHeaderTable
            }
            guard type == 1 else { continue } // PT_LOAD
            guard fileSize <= memorySize,
                  fileOffset <= UInt64(data.count),
                  fileSize <= UInt64(data.count) - fileOffset else {
                throw LoadError.invalidSegment
            }

            let loadAddress = physicalAddress == 0 ? virtualAddress : physicalAddress
            guard loadAddress <= memory.size,
                  memorySize <= memory.size - loadAddress,
                  fileSize <= UInt64(Int.max),
                  loadAddress <= UInt64(Int.max),
                  memorySize <= UInt64(Int.max),
                  total <= UInt64.max - memorySize else {
                throw LoadError.segmentOutsideGuestMemory
            }

            let segment = Segment(guestAddress: loadAddress,
                                  fileSize: fileSize,
                                  memorySize: memorySize,
                                  flags: flags)
            segments.append(segment)
            pending.append((segment, Int(fileOffset)))
            total += memorySize
        }

        guard !segments.isEmpty else { throw LoadError.noLoadableSegments }
        guard segments.contains(where: {
            entry >= $0.guestAddress && entry - $0.guestAddress < $0.memorySize
        }) else {
            throw LoadError.invalidSegment
        }

        // Clear all segment memory first, then copy all file-backed bytes.
        // This also ensures BSS is zeroed without clearing overlapping data.
        for (segment, _) in pending {
            guard memory.write(Data(count: Int(segment.memorySize)),
                               offset: segment.guestAddress) else {
                throw LoadError.segmentOutsideGuestMemory
            }
        }
        for (segment, fileOffset) in pending where segment.fileSize > 0 {
            let count = Int(segment.fileSize)
            let bytes = data.subdata(in: fileOffset..<(fileOffset + count))
            guard memory.write(bytes, offset: segment.guestAddress) else {
                throw LoadError.segmentOutsideGuestMemory
            }
        }

        return Image(entryPoint: entry, machine: machine,
                     segments: segments, loadedByteCount: total)
    }

    private func u16(_ data: Data, _ offset: Int) -> UInt16? {
        guard offset >= 0, offset <= data.count, data.count - offset >= 2 else { return nil }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func u32(_ data: Data, _ offset: Int) -> UInt32? {
        guard offset >= 0, offset <= data.count, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 |
            UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private func u64(_ data: Data, _ offset: Int) -> UInt64? {
        guard let low = u32(data, offset), let high = u32(data, offset + 4) else { return nil }
        return UInt64(low) | UInt64(high) << 32
    }
}
