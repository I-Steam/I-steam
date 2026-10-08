import Foundation

struct QEMUCommandBuilder {
    let configuration: VMConfiguration

    func arguments(diskImage: URL? = nil, firmware: URL? = nil) -> [String] {
        var args = [
            "-machine", "q35",
            "-nodefaults",
            "-display", "none",
            "-m", "\(configuration.memoryMB)",
            "-smp", "\(configuration.cpuCount)",
            "-cpu", "max",
            "-accel", configuration.accelerator == .jit ? "tcg,tb-size=512,split-wx=on" : "tcg",
            "-device", configuration.gpu.rawValue
        ]
        if configuration.gpu == .virtioGPUGL || configuration.gpu == .virtioRAMFBGL {
            args += ["-display", "egl-headless,gl=on"]
        }
        if let firmware { args += ["-drive", "if=pflash,format=raw,readonly=on,file=\(firmware.path)"] }
        if let diskImage { args += ["-drive", "if=virtio,format=qcow2,file=\(diskImage.path)"] }
        return args
    }
}
