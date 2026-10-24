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
        '"-device", VMConfiguration.GPUModel.virtioGPU.rawValue',
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
        '"SteamOS Gaming Mode"', 'VMConfiguration.defaultSteamOS',
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

if failed:
    raise SystemExit(1)
print("QEMU bridge and SteamOS mode source checks passed.")
