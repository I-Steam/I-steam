#!/usr/bin/env python3
"""Guard against accidentally committed literal line-break escape sequences."""
from pathlib import Path
import sys

checks = {
    "iSteam/QEMUNativeBridge.c": [
        r"shutdown_fn) shutdown_fn(ISTEAM_QEMU_SHUTDOWN_CAUSE_HOST_UI);\n",
    ],
    "src/QEMU/QEMUNativeRuntime.swift": [
        r"var isRunning: Bool { isteam_qemu_is_running() }\n",
        r"var lastError: String? {\n",
    ],
    "src/QEMU/QEMUBackend.swift": [
        r"var isRunning: Bool { runtime.isRunning }\n",
    ],
}
failed = False
for name, forbidden in checks.items():
    source = Path(name).read_text(encoding="utf-8")
    for token in forbidden:
        if token in source:
            print(f"{name}: found literal escaped line break around {token!r}", file=sys.stderr)
            failed = True
if failed:
    raise SystemExit(1)
print("QEMU source formatting checks passed.")
