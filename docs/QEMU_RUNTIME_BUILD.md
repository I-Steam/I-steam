# Building the iOS QEMU runtime

The repository's i-Steam app code currently has the in-process QEMU bridge and a VNC display client, but it does not contain a compiled device-arm64 QEMU runtime. Without that runtime, i-Steam cannot boot a guest OS.

## Build workflow

Run the GitHub Actions workflow **Build UTM iOS QEMU runtime (manual)** from the Actions tab. It checks out UTM with submodules, builds its dependency sysroot for physical iOS arm64, builds the upstream iOS archive, and uploads an artifact named `iSteam-qemu-runtime-ios-arm64`.

The build is deliberately manual: dependency compilation is resource-intensive and should not run for every nightly release. The artifact includes the upstream archive, dependency sysroot, a runtime-file inventory, and build information.

## Important integration work still required

This workflow is a reproducible upstream build and discovery step, **not an automatic i-Steam runtime installer**. Before copying anything into i-Steam:

1. Inspect the artifact inventory and select the exact QEMU library and its dependent libraries.
2. Confirm it exports the exact lifecycle ABI expected by `iSteam/QEMUNativeBridge.c`: `qemu_init`, `qemu_main_loop`, and `qemu_cleanup`; verify shutdown export separately.
3. Confirm the library is built for physical iOS arm64 and that its dependencies, install names, rpaths, and data files are packaged correctly.
4. Adapt and package the matching QEMU data directory at `iSteam.app/QEMU` and the library in `iSteam.app/Frameworks` or the supported bundle path.
5. Ensure all embedded executable code is signed consistently with the app. Then add a release-workflow smoke check that inspects the IPA for the library, data files, architectures, and required symbols.
6. Boot a redistributable test image on a physical iPad and verify display, keyboard, pointer, controller, storage, networking, and shutdown.

UTM's source changes over time; the workflow records the checked-out upstream revision in the GitHub run logs. Review the upstream license and preserve all required notices before redistributing runtime binaries.

## Upstream instructions

- [UTM iOS development guide](https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md)
- [UTM dependency build script](https://github.com/utmapp/UTM/blob/main/scripts/build_dependencies.sh)
- [UTM app build script](https://github.com/utmapp/UTM/blob/main/scripts/build_utm.sh)
