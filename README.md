# i-Steam

> An *experimental, community-driven* iOS and tvOS project exploring a Steam-oriented library, guest-runtime architecture, and virtual-machine concepts.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://makeapullrequest.com)
[![i-Steam Build & Release](https://github.com/I-Steam/I-steam/actions/workflows/release.yml/badge.svg)](https://github.com/I-Steam/I-steam/actions/workflows/release.yml)
[![GitLab pipeline](https://gitlab.com/chantinlongxthrx/I-steam/badges/main/pipeline.svg)](https://gitlab.com/chantinlongxthrx/I-steam/-/pipelines)

[**GitHub**](https://github.com/I-Steam/I-steam) · [**All releases**](https://github.com/I-Steam/I-steam/releases) · [**Nightly builds**](https://github.com/I-Steam/I-steam/releases/tag/nightly) · [**GitLab mirror**](https://gitlab.com/chantinlongxthrx/I-steam) · [**AltStore source**](https://i-steam.github.io/AltSource.json)

![Alt](https://repobeats.axiom.co/api/embed/60c92ea5e53d1048f89bf703d5444e243a2c5244.svg "Repobeats analytics image")

i-Steam is a Steam-oriented game library and guest-runtime experience might look like on Apple mobile devices. The repository contains an iOS app, native helper code, runtime experiments, and an early Apple TV interface.

> [!WARNING]
> **i-Steam is experimental and is not yet a working PC emulator.** It does not currently boot arbitrary Windows/Linux images through a fully integrated emulator or promise that Steam games will run. The tvOS interface is a prototype, not a game launcher. CI IPAs are unsigned; installation requires a compatible signing method, and packaging success does not prove the app works on a device.

## Downloads

Choose the build channel and platform below. Nightly builds contain recent changes and may be unstable; Main is the project's main release channel.

| Channel | iOS | tvOS |
| --- | --- | --- |
| **Main** | [Download iOS IPA](https://github.com/I-Steam/I-steam/releases/tag/main) | [Download tvOS IPA](https://github.com/I-Steam/I-steam/releases/tag/main) |
| **Nightly** | [Download nightly IPA](https://github.com/I-Steam/I-steam/releases/tag/nightly) | [Download nightly IPA](https://github.com/I-Steam/I-steam/releases/tag/nightly) |

Each release contains both platform packages and SHA-256 checksum files. Open the release page and choose the asset for your device. These are unsigned prototype packages and must be signed before installation.

### Add the AltStore source

Use the source URL below in a compatible AltStore-based app. Source availability depends on the website publishing workflow and the configured repository token.

```text
https://i-steam.github.io/AltSource.json
```

[Open AltStore source JSON]([https://i-steam.github.io/AltSource.json](https://altdirect.app/?url=https://i-steam.github.io/AltSource.json)) · [SideStore installation guide](https://docs.sidestore.io/)

The source includes separate entries for iOS Main, iOS Nightly, tvOS Main, and tvOS Nightly when published. Apple TV sideloading support depends on the installer and device; an IPA link alone does not guarantee tvOS installation.

## Features and project status

### iOS app

- Experimental library and import flows for executable and operating-system files.
- Local VM/session configuration and last-session metadata.
- File selection and shared-directory handling.
- Bounded, read-only metadata inspection for Windows PE and Linux ELF files.
- Guest-memory and block-device prototypes.
- Early display, Metal presentation, frame-pacing, keyboard, controller, and JIT-related experiments.
- Research into app-container and binary-execution approaches used by projects such as LiveContainer.

These are works in progress. Importing a file or inspecting its metadata does not execute it, and a storage prototype is not a complete virtual storage controller. JIT behavior depends on iOS version, device, signing, entitlements, and supported tooling; i-Steam does not enable JIT for every app.

### tvOS app

The tvOS target is an early Siri Remote-friendly interface preview. Its Launch session, Steam Store, and Settings actions currently display explanatory notices. It does **not** boot an operating system or launch games.

See [the tvOS status and roadmap](docs/TVOS.md).

### Runtime and native helpers

The repository contains exploratory components for guest memory, image/file inspection, storage, display, and host-device services. A complete full-system CPU/machine emulator, integrated QEMU runtime, Box64 execution environment, Wine/Proton, Windows API compatibility layer, functional guest networking/input path, and production-ready 3D GPU translation are not yet integrated. Android selection is a UI experiment. Compatibility with arbitrary games or anti-cheat systems is not promised.

## Requirements

### To build from source

- A Mac running a compatible version of Xcode.
- XcodeGen, installable with Homebrew: `brew install xcodegen`.
- Git and an iPhone/iPad or Apple TV simulator for testing.
- Physical-device installation requires appropriate signing and provisioning.

The project currently declares iOS 16 and tvOS 17 deployment targets. Confirm the current project settings and CI logs for exact SDK compatibility.

### Installation notes

- **Unsigned IPA:** use a compatible signer and follow that tool's installation instructions.
- **AltStore source:** add `https://i-steam.github.io/AltSource.json` in a compatible app.
- **Troubleshooting:** include your device/OS version and the relevant build or crash log when reporting an issue.
- **File access:** iOS file-picker access and persistent bookmark access are different; a selected file may not remain accessible if its security-scoped bookmark cannot be created or reopened.

## Building

Generate the Xcode project:

```sh
brew install xcodegen
xcodegen generate --spec project.yml
```

Open `iSteam.xcodeproj` in Xcode and choose a scheme:

- `iSteam` — iOS main build.
- `iSteamNightly` — iOS nightly build.
- `iSteamTV` — tvOS prototype.

For hosted builds, use the [Build & Release workflow](https://github.com/I-Steam/I-steam/actions/workflows/release.yml).

## Build and release channels

- **Push to `main`:** starts the Nightly channel.
- **Scheduled workflow:** runs daily at 02:00 UTC.
- **Manual GitHub Actions run:** choose **Nightly** or **Main**.
- **Manual GitLab pipeline:** can dispatch the GitHub workflow.
- **Release assets:** iOS IPA, tvOS IPA, and SHA-256 checksum files.
- **Older releases:** the workflow is configured not to automatically delete old releases.

Website/AltStore-source publishing requires the `PAGES_TOKEN` secret to have suitable write access to [the website repository](https://github.com/I-Steam/I-steam.github.io). Builds are unsigned prototypes. ZIP and checksum validation verify packaging integrity only, not installability, runtime behavior, or guest OS compatibility.

More details: [Installation](INSTALL.md) · [Release workflow](docs/RELEASES.md) · [tvOS roadmap](docs/TVOS.md).

## Contributing

Bug reports, documentation improvements, and focused pull requests are welcome. Please read the [contribution guide](CONTRIBUTING.md) before submitting changes.

## Documentation

- [Installation guide](INSTALL.md)
- [Contribution guide](CONTRIBUTING.md)
- [Build and release workflow](docs/RELEASES.md)
- [tvOS status and roadmap](docs/TVOS.md)
- [Host-device bridge](docs/HOST_DEVICE_BRIDGE.md)
- [Runtime architecture and roadmap](docs/SHARPEMU_REUSE_NOTES.md)

## Credits and technical references

These projects are research references; listing them does not mean their code is bundled here or that their maintainers endorse i-Steam.

- [QEMU](https://www.qemu.org/) — full-system emulation reference.
- [Box64](https://github.com/ptitSeb/box64) — x86-64 user-mode emulation reference.
- [StikDebug](https://github.com/StephenDev0/StikDebug) — JIT-related iOS development reference.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) and [LiveExec32](https://github.com/LiveContainer/LiveExec32) — iOS app-container and binary-execution research.
- [MeloNX](https://github.com/AzureDominus/melonx) — iOS emulator UI and performance reference.
- [SharpEmu](https://github.com/sharpemu/sharpemu) — emulator architecture research reference.
- [SideStore](https://sidestore.io/) — iOS signing and installation reference.

Third-party projects retain their own licenses and copyrights. Review upstream licenses and notices before redistributing code. No endorsement is implied.

## License and disclaimer

i-Steam is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See [LICENSE](LICENSE).

i-Steam is not affiliated with, endorsed by, or sponsored by Valve Corporation. Steam is a trademark of Valve Corporation. No particular game or operating system is guaranteed to run. AI assistants, including ChatGPT and Claude, have been used as development aids; all changes are still being reviewed and tested by maintainers.
