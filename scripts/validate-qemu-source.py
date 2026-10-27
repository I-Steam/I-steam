#!/usr/bin/env python3
"""Guard against malformed QEMU bridge source and accidental regressions."""
from pathlib import Path
import sys

required = {
    "src/QEMU/QEMUVNCClient.swift": [
        "private func performHandshake(_ connection: NWConnection) async throws",
        "case 0: // FramebufferUpdate",
        "func tapKey(_ key: String)",
        "numberOfColours = Int(Self.u16(header, 3))",
    ],
    "src/QEMU/QEMUCommandBuilder.swift": [
        '"-vnc", "127.0.0.1:0"',
        '"-device", configuration.gpu.rawValue',
        'configuration.name == "SteamOS Gaming Mode"',
    ],
    "src/Display/VMDisplayViewController.swift": [
        "vncClient.onFrame", "vncClient.start()", "vncClient.tapKey(key)"
    ],
    "src/QEMU/QEMUNativeRuntime.swift": [
        "QEMURuntimeStatus.inspect()", "isteam_qemu_start", "isteam_qemu_request_stop"
    ],
    "iSteam/QEMUNativeBridge.c": [
        'dlsym(library, "qemu_init")',
        'dlsym(library, "qemu_main_loop")',
        'dlsym(library, "qemu_cleanup")',
    ],
    "iSteam/LaunchSetupViewController.swift": [
        '"SteamOS Gaming Mode"', "VMConfiguration.defaultSteamOS",
    ],
    "src/Display/TouchGamepadView.swift": [
        'iSteam.touchGamepad.layout.v3',
        "control.center.x / bounds.width",
        "control.center.y / bounds.height",
        "if bounds.size != lastBoundsSize",
        "installEditGesturesIfNeeded()",
    ],
}
failed = False
for name, tokens in required.items():
    source = Path(name).read_text(encoding="utf-8")
    for token in tokens:
        if token not in source:
            print(f"{name}: missing required integration {token!r}", file=sys.stderr)
            failed = True

# Catch the accidental literal backslash-n that previously entered Swift comments.
builder = Path("src/QEMU/QEMUCommandBuilder.swift").read_text(encoding="utf-8")
if r"\n" in builder:
    print("src/QEMU/QEMUCommandBuilder.swift: literal escaped newline found in source", file=sys.stderr)
    failed = True


# A release IPA must never be published without its native QEMU runtime.
release_workflow = Path(".github/workflows/release.yml").read_text(encoding="utf-8")
runtime_download_start = release_workflow.find("- name: Download required iOS QEMU runtime artifact")
runtime_download_end = release_workflow.find("\n      - uses: actions/cache@v4", runtime_download_start)
if runtime_download_start < 0 or runtime_download_end < 0:
    print("release workflow: required QEMU runtime download step is missing", file=sys.stderr)
    failed = True
else:
    runtime_download = release_workflow[runtime_download_start:runtime_download_end]
    for token in ["uses: actions/download-artifact@v4", "name: iSteam-qemu-runtime-ios-arm64", "path: build/qemu-runtime"]:
        if token not in runtime_download:
            print(f"release workflow: required same-run runtime download setting missing: {token}", file=sys.stderr)
            failed = True
    if "needs: qemu-runtime" not in release_workflow:
        print("release workflow: platform builds must depend on the same-run qemu-runtime job", file=sys.stderr)
        failed = True
    if "continue-on-error:" in runtime_download or "if_no_artifact_found: warn" in runtime_download:
        print("release workflow: runtime download must fail closed", file=sys.stderr)
        failed = True

ios_package_start = release_workflow.find("- name: Build and package iOS IPA")
ios_package_end = release_workflow.find("\n      - name: Build and package tvOS IPA", ios_package_start)
if ios_package_start < 0 or ios_package_end < 0:
    print("release workflow: iOS package step is missing", file=sys.stderr)
    failed = True
else:
    ios_package = release_workflow[ios_package_start:ios_package_end]
    for token in [
        'test -s "$RUNTIME_DIR/QEMU/runtime-library-path.txt"',
        'test -s "$RUNTIME_DIR/exports.txt"',
        'grep -Eq \' _?qemu_init$\' "$RUNTIME_DIR/exports.txt"',
        'grep -Eq \' _?qemu_main_loop$\' "$RUNTIME_DIR/exports.txt"',
        'grep -Eq \' _?qemu_cleanup$\' "$RUNTIME_DIR/exports.txt"',
    ]:
        if token not in ios_package:
            print(f"release workflow: runtime packaging guard missing: {token}", file=sys.stderr)
            failed = True
    if "No verified QEMU runtime artifact is available" in ios_package:
        print("release workflow: must not silently publish IPA without QEMU", file=sys.stderr)
        failed = True

if failed:
    raise SystemExit(1)
print("QEMU bridge, runtime packaging guards, SteamOS mode, and adaptive gamepad source checks passed.")
