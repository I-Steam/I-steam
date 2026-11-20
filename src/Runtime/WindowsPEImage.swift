import Foundation

/// Bounded parser for x86-64 PE32+ images. Reads metadata only; never maps or executes guest code.
struct WindowsPEImage {
    struct DataDirectory { let rva: UInt32; let size: UInt32 }
    struct Section {
        let name: String
        let virtualAddress: UInt32
        let virtualSize: UInt32
        let rawOffset: UInt32
        let rawSize: UInt32
        let characteristics: UInt32
    }
    struct Import { let library: String; let name: String?; let ordinal: UInt16?; let hint: UInt16? }
    struct Relocation { let rva: UInt32; let type: UInt16 }

    enum ParseError: LocalizedError {
        case truncated(String), invalidSignature, unsupportedMachine(UInt16)
        case unsupportedOptionalHeader(UInt16), malformed(String), resourceLimit(String), unmappedRVA(UInt32)
        var errorDescription: String? {
            switch self {
            case .truncated(let field): return "Truncated PE data while reading \(field)."
            case .invalidSignature: return "Invalid PE signature."
            case .unsupportedMachine(let value): return String(format: "Unsupported PE machine 0x%04X; expected AMD64.", value)
            case .unsupportedOptionalHeader(let value): return String(format: "Unsupported PE optional header 0x%04X; expected PE32+.", value)
            case .malformed(let reason): return "Malformed PE image: \(reason)"
            case .resourceLimit(let reason): return "PE parser safety limit reached: \(reason)"
            case .unmappedRVA(let rva): return String(format: "RVA 0x%08X is not backed by file data.", rva)
            }
        }
    }

    let machine: UInt16
    let entryPointRVA: UInt32
    let imageBase: UInt64
    let sizeOfImage: UInt32
    let sizeOfHeaders: UInt32
    let sections: [Section]
    let directories: [DataDirectory]
    let imports: [Import]
    let relocations: [Relocation]
    private let file: Data

    static func parse(url: URL) throws -> WindowsPEImage {
        try parse(Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    static func parse(_ data: Data) throws -> WindowsPEImage {
        guard data.count >= 0x40 else { throw ParseError.truncated("DOS header") }
        guard data[0] == 0x4D, data[1] == 0x5A else { throw ParseError.invalidSignature }
        let pe = Int(try u32(data, 0x3C))
        try require(data, pe, 24, "PE/COFF header")
        guard data[pe] == 0x50, data[pe + 1] == 0x45, data[pe + 2] == 0, data[pe + 3] == 0 else {
            throw ParseError.invalidSignature
        }
        let coff = pe + 4
        let machine = try u16(data, coff)
        guard machine == 0x8664 else { throw ParseError.unsupportedMachine(machine) }
        let sectionCount = Int(try u16(data, coff + 2))
        let optionalSize = Int(try u16(data, coff + 16))
        guard (1...96).contains(sectionCount) else { throw ParseError.resourceLimit("section count must be 1...96") }
        let optional = coff + 20
        try require(data, optional, optionalSize, "optional header")
        guard optionalSize >= 112 else { throw ParseError.truncated("PE32+ optional header") }
        let magic = try u16(data, optional)
        guard magic == 0x20B else { throw ParseError.unsupportedOptionalHeader(magic) }

        let entryPoint = try u32(data, optional + 16)
        let imageBase = try u64(data, optional + 24)
        let sizeOfImage = try u32(data, optional + 56)
        let sizeOfHeaders = try u32(data, optional + 60)
        guard sizeOfImage > 0, sizeOfHeaders > 0,
              UInt64(sizeOfHeaders) <= UInt64(data.count),
              sizeOfHeaders <= sizeOfImage else { throw ParseError.malformed("invalid image/header size") }

        let directoryCount = min(Int(try u32(data, optional + 108)), 16)
        guard directoryCount <= (optionalSize - 112) / 8 else { throw ParseError.truncated("data directory array") }
        var directories: [DataDirectory] = []
        for index in 0..<directoryCount {
            let offset = optional + 112 + index * 8
            directories.append(DataDirectory(rva: try u32(data, offset), size: try u32(data, offset + 4)))
        }

        let table = optional + optionalSize
        let tableSize = sectionCount.multipliedReportingOverflow(by: 40)
        guard !tableSize.overflow else { throw ParseError.malformed("section table overflow") }
        try require(data, table, tableSize.partialValue, "section table")
        var sections: [Section] = []
        for index in 0..<sectionCount {
            let offset = table + index * 40
            let nameData = data.subdata(in: offset..<(offset + 8))
            let name = String(bytes: nameData.prefix { $0 != 0 }, encoding: .ascii) ?? "section\(index)"
            let section = Section(name: name,
                virtualAddress: try u32(data, offset + 12),
                virtualSize: try u32(data, offset + 8),
                rawOffset: try u32(data, offset + 20),
                rawSize: try u32(data, offset + 16),
                characteristics: try u32(data, offset + 36))
            guard UInt64(section.rawOffset) + UInt64(section.rawSize) <= UInt64(data.count) else {
                throw ParseError.malformed("section \(name) extends beyond file")
            }
            guard UInt64(section.virtualAddress) + UInt64(max(section.virtualSize, section.rawSize)) <= UInt64(sizeOfImage) else {
                throw ParseError.malformed("section \(name) extends beyond image")
            }
            sections.append(section)
        }

        let shell = WindowsPEImage(machine: machine, entryPointRVA: entryPoint, imageBase: imageBase,
            sizeOfImage: sizeOfImage, sizeOfHeaders: sizeOfHeaders, sections: sections,
            directories: directories, imports: [], relocations: [], file: data)
        return WindowsPEImage(machine: machine, entryPointRVA: entryPoint, imageBase: imageBase,
            sizeOfImage: sizeOfImage, sizeOfHeaders: sizeOfHeaders, sections: sections,
            directories: directories, imports: try shell.readImports(),
            relocations: try shell.readRelocations(), file: data)
    }

    /// Returns a file offset only for bytes actually present in the PE file.
    /// Virtual zero-fill tails deliberately have no file offset.
    func fileOffset(forRVA rva: UInt32, length: Int = 1) throws -> Int {
        guard length >= 0 else { throw ParseError.malformed("negative RVA length") }
        let end = UInt64(rva) + UInt64(length)
        guard end <= UInt64(sizeOfImage) else { throw ParseError.unmappedRVA(rva) }
        if rva < sizeOfHeaders {
            guard end <= UInt64(file.count) else { throw ParseError.unmappedRVA(rva) }
            return Int(rva)
        }
        for section in sections {
            let start = UInt64(section.virtualAddress)
            let span = UInt64(max(section.virtualSize, section.rawSize))
            if UInt64(rva) >= start && end <= start + span {
                let delta = UInt64(rva) - start
                guard delta + UInt64(length) <= UInt64(section.rawSize) else { throw ParseError.unmappedRVA(rva) }
                let offset = UInt64(section.rawOffset) + delta
                guard offset + UInt64(length) <= UInt64(file.count) else { throw ParseError.unmappedRVA(rva) }
                return Int(offset)
            }
        }
        throw ParseError.unmappedRVA(rva)
    }

    private func readImports() throws -> [Import] {
        guard directories.count > 1 else { return [] }
        let directory = directories[1]
        guard directory.rva != 0, directory.size >= 20 else { return [] }
        var cursor = try fileOffset(forRVA: directory.rva, length: 20)
        var result: [Import] = []
        for _ in 0..<min(Int(directory.size) / 20, 4096) {
            try Self.require(file, cursor, 20, "import descriptor")
            let originalThunk = try Self.u32(file, cursor)
            let nameRVA = try Self.u32(file, cursor + 12)
            let firstThunk = try Self.u32(file, cursor + 16)
            cursor += 20
            if originalThunk == 0 && nameRVA == 0 && firstThunk == 0 { return result }
            guard nameRVA != 0, firstThunk != 0 else { throw ParseError.malformed("incomplete import descriptor") }
            let library = try readCString(atRVA: nameRVA, limit: 512)
            let thunkRVA = originalThunk == 0 ? firstThunk : originalThunk
            var terminated = false
            for index in 0..<100_000 {
                let delta = UInt64(index) * 8
                guard UInt64(thunkRVA) + delta <= UInt64(UInt32.max) else { throw ParseError.malformed("thunk RVA overflow") }
                let value = try Self.u64(file, fileOffset(forRVA: thunkRVA + UInt32(delta), length: 8))
                if value == 0 { terminated = true; break }
                if value & 0x8000_0000_0000_0000 != 0 {
                    result.append(Import(library: library, name: nil, ordinal: UInt16(value & 0xFFFF), hint: nil))
                } else {
                    guard value <= UInt64(UInt32.max) else { throw ParseError.malformed("import name RVA overflow") }
                    let nameRVA = UInt32(value)
                    let nameOffset = try fileOffset(forRVA: nameRVA, length: 2)
                    let hint = try Self.u16(file, nameOffset)
                    let (stringRVA, stringOverflow) = nameRVA.addingReportingOverflow(2)
                    guard !stringOverflow else { throw ParseError.malformed("import string RVA overflow") }
                    result.append(Import(library: library, name: try readCString(atRVA: stringRVA, limit: 4096), ordinal: nil, hint: hint))
                }
                if result.count > 250_000 { throw ParseError.resourceLimit("too many imports") }
            }
            guard terminated else { throw ParseError.resourceLimit("unterminated import thunk table") }
        }
        throw ParseError.resourceLimit("import descriptor table has no terminator")
    }

    private func readRelocations() throws -> [Relocation] {
        guard directories.count > 5 else { return [] }
        let directory = directories[5]
        guard directory.rva != 0, directory.size >= 8 else { return [] }
        let end = UInt64(directory.rva) + UInt64(directory.size)
        guard end <= UInt64(sizeOfImage) else { throw ParseError.malformed("relocation directory exceeds image") }
        var cursor = UInt64(directory.rva)
        var result: [Relocation] = []
        while cursor + 8 <= end {
            let offset = try fileOffset(forRVA: UInt32(cursor), length: 8)
            let pageRVA = try Self.u32(file, offset)
            let blockSize = Int(try Self.u32(file, offset + 4))
            guard blockSize >= 8, blockSize % 2 == 0, UInt64(blockSize) <= end - cursor else {
                throw ParseError.malformed("invalid relocation block size")
            }
            for index in 0..<((blockSize - 8) / 2) {
                let entryRVA = UInt32(cursor) + UInt32(8 + index * 2)
                let raw = try Self.u16(file, fileOffset(forRVA: entryRVA, length: 2))
                let type = raw >> 12
                if type == 0 { continue } // ABSOLUTE padding
                guard type == 10 else { throw ParseError.malformed("unsupported x64 relocation type \(type)") }
                let (target, overflow) = pageRVA.addingReportingOverflow(UInt32(raw & 0x0FFF))
                guard !overflow, UInt64(target) + 8 <= UInt64(sizeOfImage) else {
                    throw ParseError.malformed("relocation target outside image")
                }
                result.append(Relocation(rva: target, type: type))
                if result.count > 1_000_000 { throw ParseError.resourceLimit("too many relocations") }
            }
            cursor += UInt64(blockSize)
        }
        guard cursor == end else { throw ParseError.malformed("trailing relocation directory bytes") }
        return result
    }

    private func readCString(atRVA rva: UInt32, limit: Int) throws -> String {
        let offset = try fileOffset(forRVA: rva)
        let bytes = file[offset..<(offset + min(limit, file.count - offset))]
        guard let terminator = bytes.firstIndex(of: 0),
              let value = String(bytes: bytes[..<terminator], encoding: .ascii), !value.isEmpty else {
            throw ParseError.malformed("invalid or unterminated PE string")
        }
        return value
    }

    private static func require(_ data: Data, _ offset: Int, _ length: Int, _ field: String) throws {
        guard offset >= 0, length >= 0, offset <= data.count, length <= data.count - offset else {
            throw ParseError.truncated(field)
        }
    }
    private static func u16(_ data: Data, _ offset: Int) throws -> UInt16 {
        try require(data, offset, 2, "UInt16")
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    private static func u32(_ data: Data, _ offset: Int) throws -> UInt32 {
        try require(data, offset, 4, "UInt32")
        return UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
    private static func u64(_ data: Data, _ offset: Int) throws -> UInt64 {
        UInt64(try u32(data, offset)) | (UInt64(try u32(data, offset + 4)) << 32)
    }
}
