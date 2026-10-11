# Contributing to i-Steam

Thanks for your interest in contributing to i-Steam! Bug reports, documentation improvements, testing, and focused code changes are welcome.

i-Steam is an experimental project. Please help us distinguish prototypes from implemented and tested features, and avoid describing functionality as working until it has been verified.

## Before you start

1. Read the [README](README.md) to understand the project's current scope and limitations.
2. Review the [GPL-3.0 license](LICENSE) and the licenses of any third-party code you plan to reuse.
3. Search existing issues and pull requests to avoid duplicating work.
4. For larger changes, open an issue or discussion first to explain the proposal and agree on its scope.

## Ways to contribute

- **Bug reports:** describe reproducible problems, crashes, incorrect behavior, or build failures.
- **Code:** submit focused fixes, tests, accessibility improvements, or well-scoped features.
- **Documentation:** improve setup instructions, architecture notes, troubleshooting, and platform-specific guidance.
- **Testing:** report results from real devices and simulators, clearly identifying which environment was used.
- **Research:** share upstream references and explain their relevance, compatibility, and licensing.

## Reporting bugs

Please include as much of the following as you can:

- A clear title and a short description of the problem.
- Steps to reproduce the issue and what you expected to happen.
- What actually happened, including any error message.
- Device model, iOS/iPadOS or tvOS version, and whether you used a simulator or physical device.
- The app version, commit, release tag, or workflow run involved.
- Relevant build logs, crash logs, screenshots, or a link to the failing [GitHub Actions run](https://github.com/I-Steam/I-steam/actions) or [GitLab pipeline](https://gitlab.com/chantinlongxthrx/I-steam/-/pipelines).

Remove Apple IDs, signing credentials, access tokens, private URLs, and other sensitive information from logs before sharing them. Never publish certificates, provisioning profiles, private keys, or account credentials.

## Development setup

Building the Apple targets requires a Mac with a compatible version of Xcode and the relevant SDKs. The repository uses XcodeGen.

```sh
brew install xcodegen
git clone https://github.com/I-Steam/I-steam.git
cd I-steam
xcodegen generate --spec project.yml
```

Open `iSteam.xcodeproj` in Xcode and choose the appropriate scheme:

- `iSteam` — iOS main build.
- `iSteamNightly` — iOS nightly build.
- `iSteamTV` — tvOS prototype.

The project currently declares iOS 16 and tvOS 17 deployment targets; confirm the current project settings before testing. You can review documentation and make many changes without building, but code changes should be built and tested when possible.

## Making a change

1. Create a branch from the current `main` branch.
2. Keep the change focused. Separate unrelated fixes into separate pull requests.
3. Follow the existing code style and naming conventions.
4. Add or update documentation when behavior, setup, limitations, or configuration changes.
5. Add tests where practical and do not remove checks simply to make a workflow pass.
6. Run the relevant build or tests and review the complete diff before submitting.

Suggested branch names:

- `fix/short-description`
- `feature/short-description`
- `docs/short-description`

## Platform and runtime expectations

iOS and tvOS have different APIs, capabilities, signing requirements, and interaction models. Keep platform-specific code isolated where appropriate and test the target platform rather than assuming a change works on both.

Please be precise about project status:

- Importing a file or reading PE/ELF metadata does not mean that file can be executed.
- A guest-memory or block-device prototype is not a complete virtual machine.
- A successful compile or packaged IPA does not prove successful installation or launch on a physical device.
- JIT availability depends on platform restrictions, device, signing, entitlements, and supported tooling. Do not claim a universal JIT bypass.
- Do not claim Windows/Linux boot, game compatibility, networking, controller support, or GPU acceleration unless the relevant path is implemented and tested.

For changes involving third-party projects such as QEMU, Box64, LiveContainer, LiveExec32, StikDebug, MeloNX, SharpEmu, or SideStore, explain what is being reused or referenced. Check the upstream license and attribution requirements before copying or redistributing code.

## Pull request checklist

Before opening a pull request, please check the following:

- [ ] The change has a clear purpose and a descriptive title.
- [ ] The diff contains no unrelated changes or accidental generated files.
- [ ] Documentation is updated where necessary.
- [ ] Relevant builds/tests were run, or the reason they could not be run is stated.
- [ ] Platform-specific behavior and untested limitations are described accurately.
- [ ] No secrets, signing assets, personal data, or private credentials are included.
- [ ] Third-party code and assets have appropriate licenses and attribution.

In the pull request description, explain **what changed**, **why it changed**, **how it was tested**, and any known limitations. If a hosted build fails, include the workflow or pipeline link and the relevant log excerpt.

## Code of conduct

Be respectful, constructive, and welcoming. Critique ideas and code rather than people. Harassment, discrimination, threats, and deliberate disruption of project collaboration are not acceptable.

## Licensing

By submitting a contribution, you agree that it may be distributed under the project's [GNU General Public License v3.0](LICENSE). You must have the right to submit the code and must preserve applicable third-party copyright notices and license terms.

Thank you for helping improve i-Steam!
