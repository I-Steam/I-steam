# i-Steam

i-Steam is an experimental iOS frontend for exploring game-runtime and virtual-machine concepts. It is **not a finished Steam client or general-purpose Windows gaming solution**.

## Features and project status

- iOS library, launch setup, display/input settings, and diagnostics UI.
- Prototype Windows PE / Linux ELF inspection and guest-process scaffolding.
- VM configuration and display scaffolding; full-system emulation remains incomplete.
- Metal display experiments and frame-pacing/resolution settings.
- Custom touchscreen keyboard and hardware-keyboard F-key bar UI.
- CI builds an unsigned SideStore IPA and attempts a separate simulator install/launch smoke test.
- Android guest experiment toggle is a UI flag only; it does not install or boot Android.
- macOS guest option is intentionally disabled on iOS; Apple Hypervisor.framework is not available to ordinary iOS apps.

**Important warning:** Nightly releases are experimental, unsigned, and may be broken or incomplete. A successful compile/simulator test does not prove that a physical iPhone/iPad can run a guest OS or a Steam game. Imported OS images can be stored, but booting them is not implemented. Guest input injection, full QEMU integration, Box64 runtime integration, Wine/Proton, Windows API compatibility, and real 3D GPU translation are not complete.

## Install

Read **[INSTALL.md](INSTALL.md)** for downloading the correct IPA artifact and installing with SideStore. Releases contain an unsigned IPA; it must be signed before iOS can install it.

## Automated builds and releases

- [GitHub Actions build workflow](https://github.com/I-Steam/I-steam/actions/workflows/build.yml)
- [All GitHub releases](https://github.com/I-Steam/I-steam/releases)
- [All workflow runs](https://github.com/I-Steam/I-steam/actions)

Behavior:
- **Push to `main`:** builds and publishes a Nightly pre-release only after archive build, simulator smoke test, and IPA packaging pass.
- **Scheduled run:** runs nightly at 02:00 UTC and publishes a Nightly pre-release only after required steps pass.
- **Manual run:** use **Run workflow** and select `nightly` (pre-release) or `main` (non-prerelease, marked latest).
- Failed runs display a warning and summary link; **no release is published when required build/test/package steps fail**.
- Each run uses a unique tag based on the GitHub Actions run number, such as `nightly-123` or `main-124`.

## Settings and compatibility

- **Hypervisor.framework** is shown disabled on iOS because ordinary iOS apps cannot use Apple's Hypervisor.framework. Use the QEMU/JIT or interpreter prototype choices instead.
- Device Compatibility shows the current device family and iOS version plus the known hypervisor limitation.
- **Android guest experiment** is an opt-in UI flag only. Android emulation/boot support is not implemented.
- **macOS VM** is shown disabled on iOS. This project does not currently implement a macOS guest runtime.

## Credits and technical references

These links are references and inspiration, not a claim that their code is bundled in i-Steam or that their maintainers endorse this project.

- **[QEMU](https://www.qemu.org/)** — open-source machine emulation and virtualization; reference for the full-system VM direction.
- **[Box64](https://github.com/ptitSeb/box64)** — x86-64 user-mode emulation project; reference for possible runtime work.
- **[StikDebug](https://github.com/StephenDev0/StikDebug)** — reference for JIT-related workflows and iOS development.
- **[LiveExec32](https://github.com/LiveContainer/LiveExec32)** — 32-bit binary execution on 64-bit iOS; architectural reference only, not integrated as a complete runtime.
- **[MeloNX](https://github.com/AzureDominus/melonx)** — iOS emulator project referenced for UI/performance ideas; not integrated into i-Steam.
- **[SideStore](https://sidestore.io/)** and [documentation](https://docs.sidestore.io/) — installation/signing guidance.

Third-party projects retain their own licenses and copyrights. Check each upstream license and required notices before redistributing code or binaries. No endorsement is implied.

## Disclaimer

i-Steam is not affiliated with, endorsed by, or sponsored by Valve Corporation or Steam. Steam is a Valve trademark. The project does not bypass anti-cheat systems and does not promise games requiring kernel drivers will work.
