# iOS host-device bridge

The app-side bridge is implemented in `src/Runtime/HostDeviceBridge.swift`.

## Available now
- A sandboxed `Documents/GuestShared/` directory.
- Safe read/write helpers for relative paths (rejects absolute paths and traversal).
- Basic iOS device and low-power-mode information.
- Atomic writes for files placed in the shared directory.

## Not yet connected to a running guest
The current project does not yet include a real CPU emulator, QEMU process, virtio-serial device, virtio-fs/9p device, or guest network stack. Therefore a guest OS cannot directly call this bridge yet. The next integration step is to connect these host services to a supported emulator transport, preferably QEMU user-mode networking for TCP forwarding plus virtio-serial for host RPC/file transfer. Merely opening a TCP listener in the iOS app would not make it reachable from a guest whose virtual NIC is not implemented.

## Security
Keep host access opt-in, expose only the dedicated shared directory, reject path traversal, and never expose arbitrary host filesystem paths to guest code. Clipboard and other privileged device services should require an explicit per-VM permission.
