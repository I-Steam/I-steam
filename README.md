# i-Steam

> [!DISCLAIMER]
>
> **please read this before using this application**
> **Important Notice Regarding I-steams current development stage**
>
> I-steam is still in development and is still highly unstable, which means **you may lose your data or get banned**.
>
> Furthermore, please note that we do not provide any support for issues of these development builds. and **we will not take responsibility for any possessions lost whilst using this application**. please use this application at your own risk
> **by using this application you agree to all the notices above**

> An experimental, community-driven iOS, tvOS and visionOS project exploring a Steam-oriented library, guest-runtime architecture, and virtual-machine concepts.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://makeapullrequest.com)
[![i-Steam Build & Release](https://github.com/I-Steam/I-steam/actions/workflows/release.yml/badge.svg)](https://github.com/I-Steam/I-steam/actions/workflows/release.yml)
[![GitLab pipeline](https://gitlab.com/chantinlongxthrx/I-steam/badges/main/pipeline.svg)](https://gitlab.com/chantinlongxthrx/I-steam/-/pipelines)

[**GitHub**](https://github.com/I-Steam/I-steam) · [**All releases**](https://github.com/I-Steam/I-steam/releases) · [**Nightly builds**](https://github.com/I-Steam/I-steam/releases/tag/nightly) · [**GitLab mirror**](https://gitlab.com/chantinlongxthrx/I-steam) · [**AltStore source**](https://altdirect.app/?url=https://i-steam.github.io/AltSource.json)

i-Steam is an experimental Steam-oriented game library and guest-runtime project for Apple devices. It contains an iOS app, early tvOS and visionOS targets, native helper code, runtime experiments, and portable game-library features.

> [!WARNING]
> **i-Steam is not yet a working PC emulator.** It does not currently boot arbitrary Windows/Linux images through a fully integrated emulator or promise that Steam games will run. The tvOS interface is a prototype, not a game launcher. CI IPAs are unsigned; installation requires a compatible signing method, and packaging success does not prove the app works on a device.

## DroidDeck port status

The portable native port now includes library backup/restore, per-game profile defaults, validated artwork caching, local compatibility records, and runtime-component manifest/SHA-256 verification. These are app features, not proof that a guest operating system or Windows game can run.

See [DroidDeck feature-port inventory](docs/DROIDDECK_PORT_PLAN.md) and [implemented vs unavailable status](docs/DROIDDECK_PORT_STATUS.md). Full-system QEMU, Windows Proton/Wine, FEX, Turnip/Vulkan, Flatpak/AppImage, SteamVR and vendor-specific XR support remain gated on compatible native runtimes and device validation.

## Documentation

- [Installation guide](INSTALL.md)
- [Contribution guide](CONTRIBUTING.md)
- [Build and release workflow](docs/RELEASES.md)
- [tvOS status and roadmap](docs/TVOS.md)
- [Host-device bridge](docs/HOST_DEVICE_BRIDGE.md)
- [Runtime architecture and roadmap](docs/SHARPEMU_REUSE_NOTES.md)
- [DroidDeck feature-port plan](docs/DROIDDECK_PORT_PLAN.md)
- [DroidDeck port status](docs/DROIDDECK_PORT_STATUS.md)
- Portable library transfer and profile defaults: src/Steam/DroidDeckFeatureServices.swift
- Artwork cache: src/Steam/GameArtworkStore.swift
- Compatibility records: src/Windows/GameCompatibilityDatabase.swift
- Runtime manifest verification: src/Runtime/RuntimeComponentManifest.swift

## Credits and technical references

These projects are research references; listing them does not mean their code is bundled here or that their maintainers endorse i-Steam.

- [QEMU](https://www.qemu.org/) — full-system emulation reference.
- [Box64](https://github.com/ptitSeb/box64) — x86-64 user-mode emulation reference.
- [StikDebug](https://github.com/StephenDev0/StikDebug) — JIT-related iOS development reference.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) and [LiveExec32](https://github.com/LiveContainer/LiveExec32) — iOS app-container and binary-execution research reference.
- [MeloNX](https://github.com/AzureDominus/melonx) — iOS emulator UI and performance reference.
- [SharpEmu](https://github.com/sharpemu/sharpemu) — emulator architecture research reference.
- [SideStore](https://sidestore.io/) — iOS signing and installation reference.

Third-party projects retain their own licenses and copyrights. Review upstream licenses and notices before redistributing code. No endorsement is implied.

## License and disclaimer

i-Steam is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See [LICENSE](LICENSE).

i-Steam is not affiliated with, endorsed by, or sponsored by Valve Corporation. Steam is a trademark of Valve Corporation. No particular game or operating system is guaranteed to run. AI assistants, including ChatGPT and Claude, have been used as development aids; all changes are still being reviewed and tested by maintainers.
