# i-Steam

i-Steam is an experimental iOS frontend for exploring game-runtime and virtual-machine concepts. It is **not a finished Steam client or general-purpose Windows gaming solution**.

## Features and project status
- iOS library, launch setup, display/input settings, and diagnostics UI.
- Prototype Windows PE / Linux ELF inspection and guest-process scaffolding.
- VM configuration and display scaffolding; full-system emulation remains incomplete.
- Metal display experiments and frame-pacing/resolution settings.
- Custom touchscreen keyboard and hardware-keyboard F-key bar UI.
- CI builds an unsigned SideStore IPA and tests a separate simulator build.

Launch choices are prototypes, not proof an OS or game can boot. Imported OS images can be stored, but booting them is not implemented. Touch keyboard events still need a functioning guest-input bridge. Do not assume QEMU, Box64, Wine/Proton, Windows APIs, or GPU translation are fully integrated. A simulator launch does not guarantee physical-device or LiveContainer compatibility.

## Install
Read **[INSTALL.md](INSTALL.md)** for downloading the correct IPA artifact and installing with SideStore. Releases contain an unsigned IPA; it must be signed before iOS can install it.

## Automated builds and releases
Open [GitHub Actions](https://github.com/I-Steam/I-steam/actions/workflows/build.yml) to inspect build logs and artifacts.

- **Push to `main`:** builds and publishes a GitHub **Nightly pre-release** after the build and simulator smoke test pass.
- **Scheduled run:** runs nightly at 02:00 UTC and publishes a **Nightly pre-release** if all tests pass.
- **Run workflow manually:** in GitHub Actions choose **Run workflow**, then select **nightly** (pre-release) or **main** (non-prerelease, marked latest). Failed builds do not publish a release because the release step runs only after successful earlier steps.
- Each run uses a unique tag based on the GitHub Actions run number, for example `nightly-123` or `main-124`.

See [all releases](https://github.com/I-Steam/I-steam/releases) or [workflow runs](https://github.com/I-Steam/I-steam/actions/workflows/build.yml).

## Credits and acknowledgements
This project is independently developed. These projects are acknowledged as inspiration or technical references; this does not imply their code is included or that they endorse i-Steam.

- **[QEMU](https://www.qemu.org/)** — open-source machine emulation and virtualization; reference for the full-system VM direction.
- **[Box64](https://github.com/ptitSeb/box64)** — x86-64 user-mode emulation project; reference for possible runtime work.
- **[StikDebug](https://github.com/StephenDev0/StikDebug)** — reference for JIT-related workflows and iOS development.
- **LiveExec32** — architectural inspiration; exact upstream URL and license must be verified before treating it as a dependency.
- **MeloNX** — inspiration for emulator UI/performance ideas; exact upstream project/fork should be specified.

Third-party projects retain their licenses and copyrights. Verify upstream repositories, licenses, and required notices before redistributing third-party source or binaries. No endorsement is implied.

## Disclaimer
i-Steam is not affiliated with, endorsed by, or sponsored by Valve Corporation or Steam. Steam is a Valve trademark. The project does not bypass anti-cheat systems and does not promise games requiring kernel drivers will work.
