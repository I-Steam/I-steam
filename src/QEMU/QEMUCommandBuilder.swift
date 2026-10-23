import Foundation

/// QEMU's block driver must match the image container. Guessing qcow2 for every
/// file makes ordinary raw installer images fail before firmware can boot.
enum QEMUDiskImageFormat: String {
    case raw
    case qcow2

    static func detect(at url: URL) -> QEMUDiskImageFormat {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .raw }
        defer { try? handle.close() }
        // qcow2 starts with the four-byte magic 0x514649fb ("QFI\xfb").
        guard let header = try? handle.read(upToCount: 4), header?.count == 4 else { return .raw }
        return header == Data([0x51, 0x46, 0x49, 0xfb]) ? .qcow2 : .raw
    }
}

struct QEMUCommandBuilder {
    let configuration: VMConfiguration

    func arguments(diskImage: URL? = nil, firmware: URL? = nil) -> [String] {
        // Construct one machine option; repeated -machine arguments are
        // ambiguous and can cause QEMU to reject or override configuration.
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
            args += ["-device", "qemu-xhci"]
            args += ["-device", "usb-kbd"]
            args += ["-device", "usb-tablet"]
            args += ["-device", "virtio-rng-pci"]
            args += ["-device", "virtio-balloon-pci"]
        }

        if configuration.gpu == .virtioGPUGL || configuration.gpu == .virtioRAMFBGL {
            args += ["-display", "egl-headless,gl=on"]
        } else {
            args += ["-display", "none"]
        }

        if let firmware {
            args += ["-drive", "if=pflash,format=raw,readonly=on,file=\(firmware.path)"]
        }
        if let diskImage {
            let format = QEMUDiskImageFormat.detect(at: diskImage).rawValue
            args += ["-drive", "if=virtio,format=\(format),file=\(diskImage.path)"]
        }

        return args
    }
}
