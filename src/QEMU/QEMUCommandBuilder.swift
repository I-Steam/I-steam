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
        guard let header = try? handle.read(upToCount: 512), !header.isEmpty else { return .raw }
        if header.count >= 4, header.prefix(4) == Data([0x51, 0x46, 0x49, 0xfb]) { return .qcow2 }
        if header.count >= 4, header.prefix(4) == Data([0x4b, 0x44, 0x4d, 0x56]) { return .vmdk }
        if let prefix = String(data: header.prefix(32), encoding: .ascii),
           prefix.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("# Disk DescriptorFile") { return .vmdk }
        if header.count >= 8, String(data: header.prefix(8), encoding: .ascii) == "vhdxfile" { return .vhdx }
        return .raw
    }
}

struct QEMUCommandBuilder {
    let configuration: VMConfiguration

    func arguments(diskImage: URL? = nil, firmware: URL? = nil) -> [String] {
        let needsUSBInput = configuration.bootWindows || configuration.name == "SteamOS Gaming Mode"
        let machine = needsUSBInput ? "q35,usb=on" : "q35"
        var args = [
            "-machine", machine, "-nodefaults",
            "-m", "\(configuration.memoryMB)", "-smp", "\(configuration.cpuCount)",
            "-cpu", "max",
            "-accel", configuration.accelerator == .jit ? "tcg,tb-size=512,split-wx=on" : "tcg",
            // VNC is the current display backend, so use a portable 2D device.
            "-device", VMConfiguration.GPUModel.virtioGPU.rawValue,
            "-rtc", "base=utc,clock=host"
        ]
        let bootFromISO = diskImage.map(Self.isISO9660) ?? false
        args += ["-boot", bootFromISO ? "order=d,menu=on,strict=off" : "order=c,menu=on,strict=off"]
        args += ["-netdev", "user,id=isteam-net0", "-device", "virtio-net-pci,netdev=isteam-net0", "-device", "virtio-rng-pci"]
        if needsUSBInput {
            args += ["-device", "qemu-xhci", "-device", "usb-kbd", "-device", "usb-tablet"]
        }
        if configuration.bootWindows {
            args += ["-device", "virtio-balloon-pci"]
        }

        // Expose the built-in QEMU VNC server on loopback only. QEMUVNCClient
        // consumes raw framebuffer rectangles and routes keyboard/pointer events.
        args += ["-vnc", "127.0.0.1:0"]
        if let firmware {
            args += ["-drive", "if=pflash,format=raw,readonly=on,file=\(firmware.path)"]
        }
        if let diskImage {
            if bootFromISO {
                args += ["-cdrom", diskImage.path]
            } else {
                let format = QEMUDiskImageFormat.detect(at: diskImage).rawValue
                args += ["-drive", "if=virtio,format=\(format),file=\(diskImage.path)"]
            }
        }
        return args
    }

    private static func isISO9660(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: 32_769)
            return try handle.read(upToCount: 5) == Data("CD001".utf8)
        } catch {
            return false
        }
    }
}
