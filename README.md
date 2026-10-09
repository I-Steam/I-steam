# i-Steam

i-Steam is an experimental iOS frontend for exploring game-runtime and virtual-machine concepts. It is **not a finished Steam client or general-purpose Windows gaming solution**.

## What is in the project
- iOS library, launch setup, display/input settings, and diagnostics UI.
- Prototype Windows PE / Linux ELF inspection and guest-process scaffolding.
- VM configuration and display scaffolding, with QEMU/TCG as a planned full-system emulation direction.
- Metal display experiments and frame-pacing/resolution settings.
- Custom touchscreen keyboard and hardware-keyboard F-key bar UI.
- CI packaging for an unsigned SideStore IPA.

## Runtime choices
The interface offers Windows VM, Windows Runtime, and Linux VM choices. These are **prototype selections**, not proof that the corresponding OS or game can boot. Apple's Hypervisor.framework is not available to ordinary iOS apps, so supported emulation approaches are required.

## Current implementation status
- **Main menu and settings:** UI flows are implemented; Boolean settings use native toggle switches.
- **Import custom OS:** image files can be copied into app storage. Booting imported ISO/disk images is not implemented.
- **Touch keyboard / F-key bar:** UI prototype. Full guest key injection requires a functioning runtime input bridge.
- **VM / game runtime:** incomplete scaffolding. Do not assume QEMU, Box64, Wine/Proton, Windows APIs, or GPU translation are fully integrated just because a menu option exists.
- **Graphics and performance:** settings and display infrastructure do not guarantee a particular FPS or game compatibility.
- **LiveContainer:** a successful build or simulator launch does not guarantee the IPA will launch in LiveContainer on a physical device.

## Install guide
See **[INSTALL.md — Install i-Steam on iPad or iPhone](INSTALL.md)** for downloading the correct artifact, installing through SideStore, and troubleshooting.

## Build and test
The [GitHub Actions workflow](https://github.com/I-Steam/I-steam/actions/workflows/build.yml) builds the iOS device app, checks executable metadata, attempts a simulator install/launch smoke test, and packages `iSteam-SideStore.ipa`.

A simulator launch test is not a physical-device test and does not verify LiveContainer compatibility. Check the workflow logs if any step fails.

## Credits and acknowledgements
This project is independently developed. These projects are acknowledged as inspiration or technical references; this does not imply that their code is included or that they endorse i-Steam.

- **[QEMU](https://www.qemu.org/)** — open-source machine emulation and virtualization project; reference for the full-system VM direction.
- **[Box64](https://github.com/ptitSeb/box64)** — x86-64 user-mode emulation project; reference for possible compatibility/runtime work.
- **[StikDebug](https://github.com/StephenDev0/StikDebug)** — reference for JIT-related workflows and iOS development.
- **LiveExec32** — architectural inspiration for guest-process execution. Add the exact upstream repository URL and its license details before treating it as a code dependency.
- **MeloNX** — inspiration for emulator UI/performance ideas. Add the exact upstream repository URL if a specific upstream or fork is intended.

Third-party projects retain their own licenses and copyrights. Before redistributing third-party source or binaries, verify the exact upstream repository, license, and required notices. Do not imply endorsement.

## Disclaimer
i-Steam is not affiliated with, endorsed by, or sponsored by Valve Corporation or Steam. Steam is a Valve trademark. This project does not bypass anti-cheat systems and does not promise that games requiring kernel drivers will work.
