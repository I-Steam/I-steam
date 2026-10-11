# tvOS / Apple TV status

## What exists

The repository defines a separate tvOS target and a small remote-friendly UI preview in `tvOSApp/AppDelegate.swift`. The screen offers Launch session, Steam Store and Settings actions, which currently display notices rather than starting a guest OS or opening a full tvOS store/settings implementation.

The combined release workflow builds the tvOS target separately and packages its app bundle as `iSteam-tvOS.ipa`. A successful archive/package check only means the expected app bundle was produced and its ZIP container passed validation.

## What does not exist yet

- The tvOS interface is not connected to the iOS guest-runtime code.
- Launch session does not boot Linux, Windows or another guest OS.
- The Steam Store action does not provide an embedded browser.
- The Settings action is a placeholder.
- There is no verified physical Apple TV runtime test in CI.
- The unsigned IPA is not directly installable as-is.

## Signing and testing

tvOS deployment requires an appropriate Apple TV development/deployment path, compatible signing/provisioning, and testing on a supported device or simulator. Do not use the iOS installation instructions for the tvOS artifact.

## Suggested next milestones

1. Define a tvOS-specific app architecture using focus/navigation patterns suited to the Siri Remote.
2. Add accessibility labels, focus-state styling and remote-navigation tests.
3. Separate shared portable runtime code from iOS-only UI and APIs.
4. Decide how the guest runtime can be supported on tvOS, including platform/JIT restrictions and memory/performance limits.
5. Add a tvOS simulator smoke test, then document separate physical-device testing.
6. Only enable runtime actions after they are connected to working, tested implementations.
