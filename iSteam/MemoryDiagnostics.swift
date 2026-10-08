import Foundation
import Darwin
enum MemoryDiagnostics {
    static var availableMemory: UInt64 { UInt64(max(0, os_proc_available_memory())) }
    static var formattedAvailableMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(min(availableMemory, UInt64(Int64.max))), countStyle: .memory)
    }
}