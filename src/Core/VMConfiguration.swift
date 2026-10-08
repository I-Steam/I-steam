import Foundation

struct VMConfiguration: Codable, Identifiable, Equatable {
    enum Architecture: String, Codable, CaseIterable { case x86_64, arm64, riscv64 }
    enum Accelerator: String, Codable, CaseIterable { case tcg, jit }
    enum GPUModel: String, Codable, CaseIterable {
        case virtioGPU = "virtio-gpu-pci"
        case virtioGPUGL = "virtio-gpu-gl-pci"
        case virtioRAMFBGL = "virtio-ramfb-gl"
    }

    let id: UUID
    var name: String
    var architecture: Architecture
    var memoryMB: Int
    var cpuCount: Int
    var accelerator: Accelerator
    var gpu: GPUModel
    var displayWidth: Int
    var displayHeight: Int
    var displayFPS: Int

    static var defaultLinux: VMConfiguration {
        VMConfiguration(
            id: UUID(), name: "Linux", architecture: .x86_64, memoryMB: 2048,
            cpuCount: 4, accelerator: .jit, gpu: .virtioGPUGL,
            displayWidth: 1280, displayHeight: 800, displayFPS: 60
        )
    }
}
