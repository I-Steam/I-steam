# Install i-Steam on iPhone or iPad

This guide covers the **unsigned iOS IPA** produced by the combined GitHub Actions workflow. The IPA must be signed with a compatible method before iOS can install and launch it.

> **Experimental software:** i-Steam does not yet provide a complete Steam/Windows/Linux gaming runtime. Installing the app does not mean imported operating systems or games will boot.

## Requirements

- A compatible iPhone or iPad.
- [SideStore](https://sidestore.io/) installed and configured using the [official documentation](https://docs.sidestore.io/).
- An IPA downloaded from a successful build/release.

## Download from a release

1. Open [i-Steam releases](https://github.com/I-Steam/I-steam/releases).
2. Open the latest **Nightly** release for testing, or **Main** if you specifically want the manually published main channel.
3. Download **`iSteam-ios.ipa`**. The same release also contains a separate tvOS IPA and SHA-256 checksum files; do not choose the tvOS file for an iPhone/iPad.
4. Optionally verify the download using the matching `.sha256` file. The checksum file must correspond to the exact IPA downloaded.

## Download from a workflow run

1. Open [GitHub Actions](https://github.com/I-Steam/I-steam/actions/workflows/release.yml).
2. Open a completed run marked **Success**.
3. In the Artifacts section, select the iOS artifact named similar to `iSteam-iOS-nightly` or `iSteam-iOS-main`.
4. Extract the downloaded artifact ZIP in Files and locate `iSteam-ios.ipa`.

Do not install the outer artifact ZIP, a checksum file, or an Xcode archive.

## Install with SideStore

1. Open SideStore.
2. Use SideStore's import/add-app action to select `iSteam-ios.ipa`.
3. Follow its signing and installation prompts.
4. If signing, pairing or refreshing fails, consult the [official SideStore documentation](https://docs.sidestore.io/).

The released IPA is **unsigned**. Saving it in Files does not install it by itself. Signing and app-refresh limits are controlled by your signing method and Apple account/device configuration.

## If using LiveContainer

Import the actual `.ipa`, not the downloaded artifact ZIP. LiveContainer compatibility is not guaranteed. If it fails, capture the complete crash log and check whether the app's executable, bundle metadata and dependencies are compatible with the current LiveContainer build.

## Troubleshooting

- **Workflow failed:** open the [workflow run](https://github.com/I-Steam/I-steam/actions/workflows/release.yml) and inspect the first failing step. A release should only be published after the required platform builds and release checks succeed.
- **IPA won't install:** make sure you downloaded `iSteam-ios.ipa`, not `iSteam-tvOS.ipa`, and sign it with a compatible method.
- **App installs but crashes:** provide the full device crash log and iOS version. A successful build/package check does not prove runtime correctness.
- **Checksum mismatch:** download the IPA and its matching checksum again from the same release.

## Current limitations

- Imported OS images are not bootable through an integrated full-system emulator yet.
- EXE files can be imported and inspected, but a complete Windows runtime is not integrated.
- QEMU, Box64, Wine/Proton, Windows APIs, guest networking/input and 3D GPU translation are incomplete.
- Android guest selection is an experiment/UI flag, not a working Android runtime.
- macOS guest launch and Apple's Hypervisor.framework are not supported by ordinary iOS apps.
- Game and anti-cheat compatibility is not guaranteed.

## Links

- [Repository](https://github.com/I-Steam/I-steam)
- [Releases](https://github.com/I-Steam/I-steam/releases)
- [Combined build workflow](https://github.com/I-Steam/I-steam/actions/workflows/release.yml)
- [SideStore](https://sidestore.io/)
- [SideStore documentation](https://docs.sidestore.io/)
- [Credits and references](README.md#credits-and-technical-references)
