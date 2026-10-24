#!/usr/bin/env python3
"""Guard against malformed QEMU bridge source and accidental regressions."""
from pathlib import Path
import sys

checks = {
    "iSteam/QEMUNativeBridge.c": [
        r"shutdown_fn) shutdown_fn(ISTEAM_QEMU_SHUTDOWN_CAUSE_HOST_UI);\\n",
    ],
    "src/QEMU/QEMUNativeRuntime.swift": [
        r"var isRunning: Bool { isteam_qemu_is_running() }\\n",
        r"var lastError: String? {\\n",
    ],
    "src/QEMU/QEMUBackend.swift": [
        r"var isRunning: Bool { runtime.isRunning }\\n",
    ],
}
required = {
    "src/QEMU/QEMUVNCClient.swift": [
        "private func performHandshake(_ connection: NWConnection) async throws",
        "case 0: // FramebufferUpdate",
        "func tapKey(_ key: String)",
        "numberOfColours = Int(Self.u16(header, 3))",
    ],
    "src/QEMU/QEMUCommandBuilder.swift": ['"-vnc", "127.0.0.1:0"'],
    "src/Display/VMDisplayViewController.swift": [
        "vncClient.onFrame", "vncClient.start()", "vncClient.tapKey(key)"
    ],
}
failed = False
for mapping, invert in ((checks, True), (required, False)):
    for name, tokens in mapping.items():
        source = Path(name).read_text(encoding="utf-8")
        for token in tokens:
            found = token in source
            if found == invert:
                print(f"{name}: {'found forbidden' if invert else 'missing required'} token {token!r}", file=sys.stderr)
                failed = True
if failed:
    raise SystemExit(1)
print("QEMU bridge formatting and VNC integration checks passed.")
