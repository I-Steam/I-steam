import Foundation

/// Small, dependency-free x86-64 interpreter for bring-up and instruction tests.
/// This is not a Linux userspace runtime: syscalls, paging, exceptions, and most
/// x86-64 instructions are intentionally unsupported and report a visible exit.
final class X86_64Interpreter: GuestCPUBackend {
    let architecture: VMConfiguration.Architecture = .x86_64
    private(set) var instructionCount: UInt64 = 0
    private let memory: GuestMemory
    private var registers = [UInt64](repeating: 0, count: 16)
    private var rip: UInt64 = 0
    private var halted = false
    private let stopLock = NSLock()
    private var stopRequested = false

    init(memory: GuestMemory) {
        self.memory = memory
    }

    func reset(entryPoint: UInt64) throws {
        guard entryPoint < memory.size else {
            throw GuestEngineError.backendNotInstalled(.x86_64)
        }
        registers = [UInt64](repeating: 0, count: 16)
        registers[4] = memory.size >= 8 ? memory.size - 8 : 0 // RSP
        rip = entryPoint
        instructionCount = 0
        halted = false
        stopLock.lock()
        stopRequested = false
        stopLock.unlock()
    }

    func requestStop() {
        stopLock.lock()
        stopRequested = true
        stopLock.unlock()
    }

    func run(maxInstructions: UInt64) throws -> GuestCPUExit {
        guard maxInstructions > 0 else { throw GuestEngineError.invalidInstructionBudget }
        if halted { return .halted }
        var executed: UInt64 = 0
        while executed < maxInstructions {
            stopLock.lock()
            let shouldStop = stopRequested
            stopLock.unlock()
            if shouldStop { return .interrupted }

            let instructionAddress = rip
            guard var opcode = fetchByte() else { return .memoryFault(address: rip) }
            var rex: UInt8 = 0
            if opcode >= 0x40 && opcode <= 0x4F {
                rex = opcode
                guard let next = fetchByte() else { return .memoryFault(address: rip) }
                opcode = next
            }

            switch opcode {
            case 0x90: // NOP
                break
            case 0xF4: // HLT
                halted = true
                instructionCount &+= 1
                return .halted
            case 0xCC: // INT3
                rip = instructionAddress
                return .unsupportedInstruction(address: instructionAddress)
            case 0xB8...0xBF: // MOV r64, imm64 (REX.W)
                guard rex & 0x08 != 0, let immediate = fetchUInt64() else {
                    rip = instructionAddress
                    return .unsupportedInstruction(address: instructionAddress)
                }
                let index = Int(opcode - 0xB8) | (rex & 0x01 != 0 ? 8 : 0)
                registers[index] = immediate
            case 0xEB: // JMP rel8
                guard let raw = fetchByte() else { return .memoryFault(address: rip) }
                rip = addSigned(Int8(bitPattern: raw), to: rip)
            case 0xE9: // JMP rel32
                guard let raw = fetchUInt32() else { return .memoryFault(address: rip) }
                rip = addSigned(Int32(bitPattern: raw), to: rip)
            case 0xE8: // CALL rel32
                guard let raw = fetchUInt32() else { return .memoryFault(address: rip) }
                let target = addSigned(Int32(bitPattern: raw), to: rip)
                guard registers[4] >= 8 else { return .memoryFault(address: registers[4]) }
                registers[4] -= 8
                guard memory.write(littleEndianBytes(rip), offset: registers[4]) else {
                    return .memoryFault(address: registers[4])
                }
                rip = target
            case 0xC3: // RET
                guard let target = readUInt64(at: registers[4]) else {
                    return .memoryFault(address: registers[4])
                }
                registers[4] &+= 8
                rip = target
            case 0x50...0x57: // PUSH r64
                let index = Int(opcode - 0x50) | (rex & 0x01 != 0 ? 8 : 0)
                guard registers[4] >= 8 else { return .memoryFault(address: registers[4]) }
                registers[4] -= 8
                guard memory.write(littleEndianBytes(registers[index]), offset: registers[4]) else {
                    return .memoryFault(address: registers[4])
                }
            case 0x58...0x5F: // POP r64
                let index = Int(opcode - 0x58) | (rex & 0x01 != 0 ? 8 : 0)
                guard let value = readUInt64(at: registers[4]) else {
                    return .memoryFault(address: registers[4])
                }
                registers[index] = value
                registers[4] &+= 8
            case 0x31, 0x33: // XOR r/m32,r32 or r32,r/m32; register-only subset
                guard let modrm = fetchByte(), modrm >> 6 == 3 else {
                    rip = instructionAddress
                    return .unsupportedInstruction(address: instructionAddress)
                }
                let reg = Int((modrm >> 3) & 7) | (rex & 0x04 != 0 ? 8 : 0)
                let rm = Int(modrm & 7) | (rex & 0x01 != 0 ? 8 : 0)
                if opcode == 0x31 { registers[rm] ^= registers[reg] }
                else { registers[reg] ^= registers[rm] }
                // This minimal core does not yet model x86 condition flags.
            case 0x0F: // Two-byte opcode map
                guard let second = fetchByte() else { return .memoryFault(address: rip) }
                if second == 0x05 { // SYSCALL — small Linux x86-64 userspace ABI subset
                    let number = registers[0] // RAX
                    switch number {
                    case 60, 231: // exit / exit_group
                        halted = true
                        instructionCount &+= 1
                        return .halted
                    case 1: // write(fd, buffer, count)
                        let descriptor = registers[7] // RDI
                        let address = registers[6] // RSI
                        let requested = registers[2] // RDX
                        guard descriptor == 1 || descriptor == 2 else {
                            registers[0] = UInt64(bitPattern: Int64(-9)) // -EBADF
                            break
                        }
                        guard requested <= 1_048_576,
                              requested <= UInt64(Int.max),
                              let bytes = memory.read(offset: address, length: Int(requested)) else {
                            registers[0] = UInt64(bitPattern: Int64(-14)) // -EFAULT
                            break
                        }
                        if let text = String(data: bytes, encoding: .utf8), !text.isEmpty {
                            EmulationLog.shared.write("[guest stdout] " + text)
                        } else if !bytes.isEmpty {
                            EmulationLog.shared.write("[guest stdout] <\\(bytes.count) non-UTF8 bytes>")
                        }
                        registers[0] = requested
                    default:
                        // Make unsupported syscalls explicit instead of silently
                        // pretending a guest OS or full Linux ABI is available.
                        rip = instructionAddress
                        return .backendUnavailable("Unsupported Linux x86-64 syscall \\(number)")
                    }
                } else {
                    rip = instructionAddress
                    return .unsupportedInstruction(address: instructionAddress)
                }
            default:
                rip = instructionAddress
                return .unsupportedInstruction(address: instructionAddress)
            }

            executed &+= 1
            instructionCount &+= 1
        }
        return .instructionLimit
    }

    private func fetchByte() -> UInt8? {
        guard let data = memory.read(offset: rip, length: 1), let value = data.first else { return nil }
        rip &+= 1
        return value
    }

    private func fetchUInt32() -> UInt32? {
        guard let data = memory.read(offset: rip, length: 4), data.count == 4 else { return nil }
        rip &+= 4
        return UInt32(data[0]) | UInt32(data[1]) << 8 | UInt32(data[2]) << 16 | UInt32(data[3]) << 24
    }

    private func fetchUInt64() -> UInt64? {
        guard let data = memory.read(offset: rip, length: 8), data.count == 8 else { return nil }
        rip &+= 8
        var result: UInt64 = 0
        for index in 0..<8 { result |= UInt64(data[index]) << UInt64(index * 8) }
        return result
    }

    private func readUInt64(at address: UInt64) -> UInt64? {
        guard let data = memory.read(offset: address, length: 8), data.count == 8 else { return nil }
        var result: UInt64 = 0
        for index in 0..<8 { result |= UInt64(data[index]) << UInt64(index * 8) }
        return result
    }

    private func littleEndianBytes(_ value: UInt64) -> Data {
        var value = value.littleEndian
        return withUnsafeBytes(of: &value) { Data($0) }
    }

    private func addSigned(_ displacement: Int8, to base: UInt64) -> UInt64 {
        displacement >= 0 ? base &+ UInt64(displacement) : base &- UInt64(-Int16(displacement))
    }

    private func addSigned(_ displacement: Int32, to base: UInt64) -> UInt64 {
        displacement >= 0 ? base &+ UInt64(displacement) : base &- UInt64(-Int64(displacement))
    }
}
