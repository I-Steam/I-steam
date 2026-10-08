# i-Steam

A native iOS emulation frontend being reworked around a UTM-style layered architecture.

## Architecture

- `src/Core` — VM configuration, lifecycle and emulation logging.
- `src/QEMU` — QEMU-style machine and command configuration.
- `src/GPU` — VirtIO-GPU-oriented graphics backend and Metal renderer.
- `src/Display` — iOS VM display surface using MetalKit.
- `iSteam/` — existing iOS UI, Box64 compatibility runtime, JIT coordination and app storage.

The target architecture is **QEMU + VirtIO GPU + Metal**, following the same layered approach used by UTM.

## GPU emulation

The first GPU layer is now in the source tree:

- VirtIO GPU device selection: `virtio-gpu-pci`, `virtio-gpu-gl-pci`, and `virtio-ramfb-gl`.
- MetalKit display backend.
- CPU-to-GPU framebuffer submission.
- 60 FPS display target.
- QEMU command generation for GL-capable virtual GPUs.

This is the host rendering and framebuffer layer. It is **not yet a complete guest 3D driver implementation**. Full 3D acceleration still requires the UTM/QEMU graphics stack, including virglrenderer and ANGLE/Metal.

## Runtime

Box64 remains available for compatible x86-64 Linux executables. The new QEMU backend is the long-term full-system path so i-Steam can eventually boot complete Linux/Windows guests instead of only launching individual ELF files.

## JIT and memory

The existing StikDebug integration and memory entitlements remain in place. JIT is important for practical QEMU TCG performance on iOS.

## Build

GitHub Actions generates the Xcode project from `project.yml`, builds the Box64 runtime, builds the new Metal GPU layer, and packages an unsigned `iSteam-SideStore.ipa` for SideStore signing.
