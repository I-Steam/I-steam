# Install i-Steam on iPad or iPhone

This guide covers installing the **unsigned SideStore IPA** produced by GitHub Actions. The app must be signed on the device before iOS can launch it.

> ⚠️ **Nightly warning:** Builds are experimental and may contain bugs or incomplete features. The app currently does not provide a complete Steam/Windows/Linux gaming runtime, and a successful device build does not prove that a guest OS or game will boot.

## Requirements

- A compatible iPhone or iPad.
- [SideStore](https://sidestore.io/) installed and paired/configured using its [official documentation](https://docs.sidestore.io/).
- The IPA artifact from a successful GitHub Actions run.

## 1. Download the IPA

1. Open [i-Steam GitHub Actions builds](https://github.com/I-Steam/I-steam/actions/workflows/build.yml).
2. Open the newest run marked **Success**. Do not use a run that is running or failed.
3. Under **Artifacts**, download **iSteam-SideStore**. GitHub downloads the artifact as a ZIP.
4. Open the ZIP in Files and extract it.
5. Locate `iSteam-SideStore.ipa`. Do not install the outer artifact ZIP or the `.xcarchive`.
6. Alternatively, check [GitHub Releases](https://github.com/I-Steam/I-steam/releases) for the latest published Nightly or Main build. Releases are published only when required build/test/package steps pass.

## 2. Install through SideStore

1. Open SideStore on the iPad/iPhone.
2. On **My Apps**, use SideStore's import/add-app action to select `iSteam-SideStore.ipa`.
3. Follow SideStore's signing and installation prompts. If pairing, refresh, or signing is required, use the [official SideStore documentation](https://docs.sidestore.io/).
4. When installation finishes, try opening iSteam.

The artifact is **unsigned**. Copying it into Files alone does not install it.

## 3. If using LiveContainer

Import the actual `.ipa`, not the artifact ZIP or Xcode archive. A LiveContainer error such as `Bad file descriptor` or an executable path ending in `/(null)` requires checking the app bundle's `Info.plist` and executable. A successful Xcode build or simulator test does not guarantee LiveContainer compatibility.

## 4. Troubleshooting failed builds

1. Open the [workflow runs](https://github.com/I-Steam/I-steam/actions).
2. Open the failed run and inspect the **first failing step**, especially any Swift compiler error.
3. No release should be published for a failed build. The workflow adds a warning and a summary link when it fails.
4. After a source fix is pushed to `main`, wait for the new workflow run to finish before downloading an IPA.

## Current limitations

- Imported OS images can be copied into app storage, but booting them is not implemented. Windows 10 requires user-supplied installation media; the project does not bundle Windows.
- EXE files can be imported into the library but cannot yet be executed by an integrated Windows runtime.
- The current IPA is iOS-only; native Apple TV support needs a separate tvOS target.
- The Android experiment switch is a UI flag only; there is no Android boot runtime.
- macOS guest launch and Apple Hypervisor.framework are disabled on iOS.
- QEMU, Box64, Wine/Proton, Windows APIs, guest input injection, and real 3D GPU translation are not fully integrated.
- Compatibility with arbitrary Steam games is not guaranteed.

## Links

- [GitHub repository](https://github.com/I-Steam/I-steam)
- [GitHub Releases](https://github.com/I-Steam/I-steam/releases)
- [GitHub Actions builds](https://github.com/I-Steam/I-steam/actions/workflows/build.yml)
- [SideStore website](https://sidestore.io/)
- [SideStore documentation](https://docs.sidestore.io/)
- [Credits and technical references](README.md#credits-and-technical-references)
