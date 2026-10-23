import Foundation

/// Supported QEMU disk containers. Detection uses file signatures rather than
/// filename extensions, which can be wrong after a user renames an image.
enum QEMUDiskImageFormat: String {
    case raw
    case qcow2
    case vmdk
    case vhdx

    static func detect(at url: URL) -> QEMUDiskImageFormat {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .raw }
        defer { try? handle.close() }

        guard let header = try? handle.read(upToCount: 512), !header.isEmpty else {
            return .raw
        }

        // qcow2: 0x514649fb ("QFI\xfb") at byte zero.
        if header.count >= 4, header.prefix(4) == Data([0x51, 0x46, 0x49, 0xfb]) {
            return .qcow2
        }
        // VMDK sparse extent: "KDMV" at byte zero. Descriptor VMDKs are
        // text files and safely fall back to raw unless a descriptor parser
        // is added; guessing a container from a .vmdk suffix is unsafe.
        if header.count >= 4, header.prefix(4) == Data([0x4b, 0x44, 0x4d, 0x56]) {
            return .vmdk
        }
        // VHDX signature is the eight ASCII bytes "vhdxfile".
        if header.count >= 8, String(data: header.prefix(8), encoding: .ascii) == "vhdxfile" {
            return .vhdx
        }
        return .raw
    }
}

struct QEMUCommandBuilder {
    let configuration: VMConfiguration

    func arguments(diskImage: URL? = nil, firmware: URL? = nil) -> [String] {
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
