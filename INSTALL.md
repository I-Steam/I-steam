# Install i-Steam on iPad or iPhone

This guide covers installing the **unsigned SideStore IPA** produced by the GitHub Actions build. The app must be signed on the device before iOS can launch it.

## Requirements
- A compatible iPhone or iPad.
- [SideStore](https://sidestore.io/) installed and paired/configured using its official guide.
- The i-Steam IPA artifact from a successful build.

## 1. Download the IPA
1. Open [i-Steam GitHub Actions builds](https://github.com/I-Steam/I-steam/actions/workflows/build.yml).
2. Open the newest run marked **Success**. Do not use a run still running or failed.
3. Under **Artifacts**, download **iSteam-SideStore**. GitHub downloads the artifact as a ZIP.
4. Open the ZIP in Files and extract it.
5. Locate `iSteam-SideStore.ipa`. Do not install the outer artifact ZIP or the `.xcarchive`.

## 2. Install through SideStore
1. Open SideStore on the iPad.
2. On **My Apps**, use SideStore's import/add-app action to select `iSteam-SideStore.ipa`.
3. Follow SideStore's signing and installation prompts. If pairing, refresh, or signing is required, use the [official SideStore documentation](https://docs.sidestore.io/).
4. When installation finishes, try opening iSteam.

The artifact is **unsigned**. Copying it into Files alone does not install it.

## 3. If using LiveContainer
Import the actual `.ipa`, not the artifact ZIP or Xcode archive. A LiveContainer error such as `Bad file descriptor` or an executable path ending in `/(null)` requires checking the app bundle's `Info.plist` and executable. A successful Xcode build or simulator test does not guarantee LiveContainer compatibility.

## 4. Troubleshooting
The CI workflow checks the device app's executable metadata, attempts a simulator install/launch smoke test, and validates the IPA archive. A simulator test is not a physical-device test or a LiveContainer test. If a build fails, open the failed workflow run and inspect the first failing step. If the app installs but crashes, record the complete device/LiveContainer error and the exact build run used.

## Current limitations
i-Steam is an early prototype. Launch-menu options do not mean every runtime is implemented. Custom OS images can be imported and stored, but booting them is not implemented yet. Compatibility with arbitrary Steam games is not guaranteed.

## Links
- [GitHub repository](https://github.com/I-Steam/I-steam)
- [GitHub Actions builds](https://github.com/I-Steam/I-steam/actions/workflows/build.yml)
- [SideStore website](https://sidestore.io/)
- [SideStore documentation](https://docs.sidestore.io/)
