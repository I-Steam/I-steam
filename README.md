# i-Steam

> i-Steam is an *experimental, community-driven* iOS project exploring Steam-library management, guest-runtime architecture, and virtual-machine concepts—with an early tvOS interface prototype.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://makeapullrequest.com)
[![i-Steam Build & Release](https://github.com/I-Steam/I-steam/actions/workflows/release.yml/badge.svg)](https://github.com/I-Steam/I-steam/actions/workflows/release.yml)
[![GitLab pipeline](https://gitlab.com/chantinlongxthrx/I-steam/badges/main/pipeline.svg)](https://gitlab.com/chantinlongxthrx/I-steam/-/pipelines)

[**GitHub repository**](https://github.com/I-Steam/I-steam) · [**Releases**](https://github.com/I-Steam/I-steam/releases) · [**GitLab mirror**](https://gitlab.com/chantinlongxthrx/I-steam)

i-Steam is an experimental app for exploring how a Steam-oriented library and guest-runtime experience could work on Apple mobile devices. The repository contains an iOS app, native helper code, runtime prototypes, and a separate Apple TV interface preview.

**This is not yet a complete PC emulator or a working way to run arbitrary Steam games.** The current project does not boot imported Windows/Linux images through a fully integrated emulator, and its tvOS interface is not connected to a working guest runtime. Builds and packaged IPAs are experimental; unsigned IPAs require a compatible signing and installation path.

Contributions, bug reports, and carefully scoped experiments are welcome!

## Requirements

### iOS development

- A Mac running a compatible version of Xcode for the project’s deployment targets.
- XcodeGen, installable with Homebrew: `brew install xcodegen`.
- Git for source control.
- A compatible iPhone or iPad for device testing.
- For installation of an unsigned CI IPA, a compatible signing method such as [SideStore](https://sidestore.io/) and its [official documentation](https://docs.sidestore.io/).

### tvOS development

- Xcode with the tvOS SDK.
- An Apple TV simulator for UI testing; physical-device testing requires the appropriate signing and provisioning setup.

The project currently declares iOS 16 and tvOS 17 deployment targets. SDK availability, signing, and actual device compatibility should be checked against the current project settings and build logs.

## Project Overview

### iOS app

The iOS app provides the main experimental library and configuration experience. Current areas include:

- Import/library UI for executable and operating-system files.
- Local VM/session configuration and last-session metadata.
- Basic file and shared-directory handling.
- Bounded, read-only metadata inspection for Windows PE and Linux ELF files.
- Guest-memory and block-device prototypes.
- Display, Metal presentation, frame-pacing, keyboard and controller experiments.
- JIT-related development and integration experiments, subject to iOS, device, signing and entitlement restrictions.

These pieces are at different stages of development. An importer or metadata inspector is not an executable runtime, and a storage primitive is not a complete virtual storage controller.

### tvOS app

The separate tvOS target is an early Siri Remote-friendly interface preview. Its Launch session, Steam Store and Settings actions currently show explanatory notices. It does **not** boot an operating system, provide an embedded Steam browser, or launch games.

See [docs/TVOS.md](docs/TVOS.md) for its current boundaries and next steps.

### Runtime and native helpers

The repository contains exploratory components for guest memory, image/file inspection, storage, display, and host-device services. These are intended as building blocks for future integration, not a claim that a complete virtual machine is already present.

The project does not yet integrate a complete full-system CPU/machine emulator, QEMU runtime, Box64 execution environment, Wine/Proton, Windows API compatibility layer, functional guest networking/input path, or production-ready 3D GPU translation. Android selection is a UI experiment only. macOS guest support and Apple’s Hypervisor.framework are not implemented for ordinary iOS app use. Compatibility with arbitrary games or anti-cheat systems is not promised.

## Building

Generate the Xcode project from the XcodeGen specification:

```sh
brew install xcodegen
xcodegen generate --spec project.yml
```

Then open the generated `iSteam.xcodeproj` in Xcode and select the appropriate scheme and destination:

- `iSteam` — iOS main build.
- `iSteamNightly` — iOS nightly build.
- `iSteamTV` — tvOS prototype.

For a device archive or IPA, use the repository’s [Build & Release workflow](.github/workflows/release.yml). CI packaging checks do not replace a physical-device launch test.

## Builds and releases

The [combined GitHub Actions workflow](https://github.com/I-Steam/I-steam/actions/workflows/release.yml) builds iOS and tvOS as separate jobs and publishes their artifacts together.

- **Push to `main`:** Nightly build.
- **Scheduled run:** Nightly build, daily at 02:00 UTC.
- **Manual GitHub Actions run:** choose `Nightly` or `Main`.
- **Manual GitLab pipeline:** choose the release channel to dispatch the GitHub workflow.
- Releases include `iSteam-ios.ipa`, `iSteam-tvOS.ipa`, and matching SHA-256 checksum files.
- Older releases are not automatically deleted by the workflow.

The IPAs are unsigned prototype artifacts. ZIP/checksum validation confirms packaging integrity only; it does not establish installability, successful runtime behavior, or guest OS compatibility. Website/AltStore-source publishing is conditional on the `PAGES_TOKEN` secret being configured with appropriate write access.

See [docs/RELEASES.md](docs/RELEASES.md) and [INSTALL.md](INSTALL.md) for details.

## Contributing

Bug reports, documentation fixes, and focused pull requests are welcome. Please:

1. Describe the problem and the device/iOS or tvOS version where relevant.
2. Include the failing workflow link or a useful crash/build log when reporting a failure.
3. Keep changes scoped and document platform-specific behavior.
4. Do not describe a feature as working unless it has been implemented and tested; distinguish compile success from real-device and guest-runtime tests.
5. Check the licenses and attribution requirements of third-party code before proposing or submitting it.

See [CONTRIBUTING.md](CONTRIBUTING.md) if present, and open an issue or pull request in the [GitHub repository](https://github.com/I-Steam/I-steam).

## Documentation

- [Installation guide](INSTALL.md)
- [Build and release workflow](docs/RELEASES.md)
- [tvOS status and roadmap](docs/TVOS.md)
- [Host-device bridge](docs/HOST_DEVICE_BRIDGE.md)
- [Runtime architecture and roadmap](docs/SHARPEMU_REUSE_NOTES.md)

## Credits and technical references

These projects are references for research and development; their presence here does not mean their code is bundled in i-Steam or that their maintainers endorse this project.

- [QEMU](https://www.qemu.org/) — full-system emulation reference.
- [Box64](https://github.com/ptitSeb/box64) — x86-64 user-mode emulation reference.
- [StikDebug](https://github.com/StephenDev0/StikDebug) — JIT-related iOS development reference.
- [LiveExec32](https://github.com/LiveContainer/LiveExec32) — binary execution architecture reference.
- [MeloNX](https://github.com/AzureDominus/melonx) — iOS emulator UI and performance reference.
- [SharpEmu](https://github.com/sharpemu/sharpemu) — emulator architecture research reference.
- [SideStore](https://sidestore.io/) — iOS signing and installation reference.

Third-party projects retain their own licenses and copyrights. Review upstream licenses and notices before redistributing any code. No endorsement is implied.

## Licensing

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See [LICENSE](LICENSE) for the full license text.

## Disclaimer

i-Steam is not affiliated with, endorsed by, or sponsored by Valve Corporation. Steam is a trademark of Valve Corporation. This project does not promise that any particular game or operating system will run.

AI assistants, including ChatGPT and Claude, have been used as development aids; changes should still be reviewed and tested by maintainers.
