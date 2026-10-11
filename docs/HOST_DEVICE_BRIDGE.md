# iOS host-device bridge

The current app-side bridge is implemented in `src/Runtime/HostDeviceBridge.swift`.

## Available now

- A sandboxed `Documents/GuestShared/` directory.
- Relative-path read/write helpers that reject absolute paths and path traversal.
- Basic device and low-power-mode information.
- Atomic writes for files placed in the shared directory.

These are host-side utilities. They are not, by themselves, a connection to a running guest operating system.

## Not yet connected to a running guest

The project does not currently include a complete CPU/system emulator, a running QEMU process, a working virtio-serial device, virtio-fs/9p transport, or a guest network stack. A guest OS therefore cannot call this bridge as a functioning guest-to-host service.

The next integration step is to choose and integrate a supported emulator transport. A possible direction is QEMU user-mode networking for TCP forwarding plus virtio-serial for host RPC/file transfer, but this requires actual emulator/device integration and tests; merely opening a TCP listener in the iOS app would not make it reachable from a guest without a virtual NIC and routing implementation.

## External drives

The app can keep references to user-selected files and disk images through iOS document-picker/security-scoped access where supported. That does **not** grant a guest direct access to a physical USB drive or automatically attach a disk image to a working virtual storage controller. Guest-visible SATA/virtio storage integration remains future work.

## Security requirements

- Keep host access opt-in and scoped to a dedicated shared directory.
- Reject path traversal and do not expose arbitrary host filesystem paths to guest code.
- Treat imported images and executables as untrusted input; use bounded parsing and validate offsets/sizes before reads.
- Require explicit per-VM permission for clipboard, network and other privileged device services.
- Do not claim isolation or sandbox guarantees that have not been tested.

## Next steps

1. Define a versioned host RPC protocol.
2. Add tests for path traversal, invalid encodings, oversized requests and interrupted writes.
3. Connect the protocol to an actual guest transport.
4. Add explicit per-VM permission prompts and observable logging.
5. Test file-transfer failure cases and ensure no host paths escape the shared directory.
