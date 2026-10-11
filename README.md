# i-Steam

i-Steam is an experimental iOS app and early tvOS interface for researching Steam-library, guest-runtime, and virtual-machine concepts. It is **not a finished Steam client, PC emulator, or general-purpose Windows gaming solution**.

- GitHub: https://github.com/I-Steam/I-steam
- GitLab mirror: https://gitlab.com/chantinlongxthrx/I-steam
- Releases: https://github.com/I-Steam/I-steam/releases
- Build history: https://github.com/I-Steam/I-steam/actions

## Current status

### iOS app

- Library/import UI for game and executable files.
- Steam Store link via the iOS app's browser experience.
- VM configuration slots and last-session metadata saved locally.
- OS-image import and external-drive/shared-directory scaffolding.
- Bounded, read-only Windows PE and Linux ELF metadata inspection.
- Guest memory, block-device, x86-64 interpreter and VM configuration prototypes.
- Metal presentation, frame pacing, resolution settings, keyboard and controller UI experiments.
- JIT-related workflow/protocol experiments; actual JIT availability depends on device, iOS version, signing, and pairing setup.

### tvOS app

- A separate Apple TV target with a basic remote-friendly interface preview.
- Launch-session, Store and Settings actions currently show explanatory notices.
- The tvOS interface is **not yet connected to the iOS guest-runtime code** and does not boot an operating system or launch Steam games.

### Important limitations

A successful compile or IPA packaging check does not prove that an app can boot a guest OS or run a game on a physical device. At present, imported OS images are not bootable through an integrated full-system emulator, imported EXE files are not executed by a complete Windows runtime, and the tvOS UI is a separate prototype.

The project does not yet provide a complete CPU/system emulator, full QEMU integration, integrated Box64 runtime, Wine/Proton, Windows API compatibility layer, functional guest networking/input bridge, or production-ready 3D GPU translation. Anti-cheat compatibility is not promised. The Android experiment switch is a UI flag only. macOS guest support and Apple's Hypervisor.framework are unavailable to ordinary iOS apps and are not implemented here.

## Install and test

- **iOS:** Read [INSTALL.md](INSTALL.md). The CI IPA is unsigned and must be signed with a compatible tool such as SideStore before installation.
- **tvOS:** See [docs/TVOS.md](docs/TVOS.md). The tvOS IPA is a packaged build artifact, not a promise of direct installability; it is unsigned and must be signed/provisioned appropriately for the target device.
- **Build/release behavior:** See [docs/RELEASES.md](docs/RELEASES.md).

## Build and release channels

The single workflow [release.yml](.github/workflows/release.yml) builds both iOS and tvOS and publishes their IPAs together in one release.

- **Automatic push to `main`:** publishes Nightly only.
- **Scheduled build:** runs daily at 02:00 UTC and publishes Nightly only.
- **Manual GitHub Actions run:** choose **Nightly** or **Main**; both platform artifacts are included in the resulting release.
- **Manual GitLab pipeline:** choose the channel input, then the GitLab pipeline dispatches the corresponding GitHub workflow run.
- Existing releases are not automatically deleted by the workflow.
- The release job runs only after both platform build jobs succeed and verifies that the IPA ZIP containers and SHA-256 checksums are valid.
- The release assets are unsigned prototypes. A structurally valid IPA is not necessarily signed or installable.

The website/AltStore source update is conditional on the `PAGES_TOKEN` secret being configured with write access to the website repository. The iOS app is the normal SideStore install target; the tvOS listing is informational and does not mean SideStore can install it on every device.

## Repository map

| Path | Purpose |
| --- | --- |
| `iSteam/` | iOS app, native helpers, resources and app configuration |
| `tvOSApp/` | Separate tvOS interface prototype |
| `src/Core/` | VM configuration, engine/session scaffolding and logs |
| `src/Runtime/` | Guest-memory, loader, process and storage prototypes |
| `src/QEMU/` | QEMU command/backend scaffolding; not a complete integrated emulator |
| `src/Display/`, `src/GPU/` | Display, input, GPU and frame-pacing experiments |
| `docs/` | Architecture, host-device bridge, release and tvOS notes |
| `.github/workflows/release.yml` | Combined iOS + tvOS CI and release workflow |
| `.gitlab-ci.yml` | GitLab-to-GitHub sync and manual workflow dispatch |

## Runtime engineering roadmap

See [docs/SHARPEMU_REUSE_NOTES.md](docs/SHARPEMU_REUSE_NOTES.md) for architecture review, bounded PE inspection, licensing cautions and staged runtime milestones. See [docs/HOST_DEVICE_BRIDGE.md](docs/HOST_DEVICE_BRIDGE.md) for current host/device bridge boundaries.

## Credits and technical references

These projects are references, not a claim that their code is bundled in i-Steam or that their maintainers endorse this project.

- [QEMU](https://www.qemu.org/) — full-system emulation reference.
- [Box64](https://github.com/ptitSeb/box64) — x86-64 user-mode emulation reference.
- [StikDebug](https://github.com/StephenDev0/StikDebug) — JIT-related iOS development reference.
- [LiveExec32](https://github.com/LiveContainer/LiveExec32) — architectural reference for binary execution on iOS.
- [MeloNX](https://github.com/AzureDominus/melonx) — iOS emulator UI/performance reference.
- [SharpEmu](https://github.com/sharpemu/sharpemu) — emulator architecture research reference; no SharpEmu source is copied as part of this documentation.
- [SideStore](https://sidestore.io/) and [official documentation](https://docs.sidestore.io/) — iOS signing and installation guidance.

Third-party projects retain their own licenses and copyrights. Check upstream licenses and required notices before redistributing code. No endorsement is implied.

## Disclaimer

i-Steam is not affiliated with, endorsed by, or sponsored by Valve Corporation. Steam is a Valve trademark. This project does not bypass anti-cheat systems and does not guarantee that any particular game will run.

AI assistants, including ChatGPT and Claude, have been used as aids during development and debugging; changes should still be reviewed and tested by maintainers.
