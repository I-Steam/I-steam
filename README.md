# i-Steam

Native iOS Xcode project for a Box64/BoxiOS-based launcher/runtime.

## Architecture
- iOS 16+
- arm64 + arm64e device target
- native Swift/C runtime bridge
- explicit memory entitlements

## JIT
Implements the universal arm64 breakpoint entry points documented by StikDebug/StikJIT and adds a StikDebug URL coordinator using the current PID and bundle ID. The UI offers **Wait for Debugger** and **StikDebug**.

The current BoxiOS snapshot itself has dynarec/JIT disabled, so the iOS JIT integration does not enable Box64 dynarec by itself.

## Memory
The target declares:
- `com.apple.developer.kernel.increased-memory-limit`
- `com.apple.developer.kernel.extended-virtual-addressing`

GetMoreRam is a signing/App ID capability tool, not a framework. If the provisioning profile drops the increased-memory capability, enable it through the appropriate signing flow before installing. The source entitlement alone cannot override a provisioning profile.

## GitHub Actions
The workflow builds the BoxiOS static library, builds the StikJIT framework as a reference artifact, builds the Xcode project for arm64/arm64e, and packages an unsigned `iSteam-SideStore.ipa`.

The IPA is intended to be signed by SideStore rather than distributed through the App Store.

## OS versions
The source deployment target is iOS 16. The JIT protocol code compiles for arm64/arm64e and the app can run on iOS 16, 17, 26 and 27. Built-in StikJIT helper-process integration is not enabled in this first build because that requires a separate iOS 17.4+ helper extension.
