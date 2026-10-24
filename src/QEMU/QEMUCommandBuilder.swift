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
        // A descriptor VMDK is a text file rather than a sparse extent.
        if let prefix = String(data: header.prefix(32), encoding: .ascii),
           prefix.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("# Disk DescriptorFile") {
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

        // Give guests a clock, a boot menu, and isolated user-mode networking.
        // User-mode networking does not bridge the iOS host's LAN or expose
        // inbound ports unless an explicit hostfwd rule is configured.
        args += ["-rtc", "base=utc,clock=host"]
        let bootFromISO = diskImage.map(Self.isISO9660) ?? false
        args += ["-boot", bootFromISO ? "order=d,menu=on,strict=off" : "order=c,menu=on,strict=off"]
        args += ["-netdev", "user,id=isteam-net0"]
        args += ["-device", "virtio-net-pci,netdev=isteam-net0"]
        args += ["-device", "virtio-rng-pci"]

        if configuration.bootWindows {
            args += ["-device", "qemu-xhci"]
            args += ["-device", "usb-kbd"]
            args += ["-device", "usb-tablet"]
            args += ["-device", "virtio-balloon-pci"]
        }

        // UTM renders through its SPICE client / renderer stack. i-Steam has
        // not ported that stack yet, so keep QEMU headless rather than requesting
        // EGL/GL backends that are not bundled on iOS. The guest will boot without
        // a visible console until the SPICE display adapter is integrated.
        args += ["-display", "none"]

        if let firmware {
            args += ["-drive", "if=pflash,format=raw,readonly=on,file=\(firmware.path)"]
        }
        if let diskImage {
            if bootFromISO {
                // ISO-9660 images are CD-ROM media, not hard disks.
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
