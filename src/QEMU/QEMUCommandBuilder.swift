import Foundation

struct QEMUCommandBuilder {
    let configuration: VMConfiguration

    func arguments(diskImage: URL? = nil, firmware: URL? = nil) -> [String] {
        // Build one machine declaration. Repeating -machine overrides/conflicts
        // with the earlier setting on several QEMU builds.
        let machine = configuration.bootWindows ? "q35,usb=on" : "q35"
        var args = [
            "-machine", machine,
            "-nodefaults",
            "-m", "\(configuration.memoryMB)",
            "-smp", "\(configuration.cpuCount)",
            "-cpu", "max",
            "-accel", configuration.accelerator == .jit ? "tcg,tb-size=512,split-wx=on" : "tcg",
            "-device", configuration.gpu.rawValue
        ]

        if configuration.bootWindows {
            args += ["-device", "virtio-rng-pci", "-device", "virtio-balloon-pci"]
        }

        // The current i-Steam renderer does not yet consume a QEMU display
        // surface. Keep QEMU headless rather than requesting EGL on iOS, where
        // the Linux egl-headless display backend is not available.
        args += ["-display", "none"]

        if let firmware {
            args += ["-drive", "if=pflash,format=raw,readonly=on,file=\(firmware.path)"]
        }
        if let diskImage {
            let ext = diskImage.pathExtension.lowercased()
            let format = ext == "qcow2" || ext == "qcow" ? "qcow2" : "raw"
            args += ["-drive", "if=virtio,format=\(format),file=\(diskImage.path)"]
        }

        return args
    }
}
