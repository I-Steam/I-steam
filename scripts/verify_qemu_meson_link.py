#!/usr/bin/env python3
"""Fail before QEMU compilation unless its actual Meson link edge uses iOS compiler-rt."""
from pathlib import Path
import sys


def verify_link(ninja_text: str, runtime_path: str) -> None:
    lines = ninja_text.splitlines()
    target_prefix = "build libqemu-x86_64-softmmu.dylib:"
    start = next((i for i, line in enumerate(lines) if line.startswith(target_prefix)), None)
    if start is None:
        raise SystemExit("QEMU build.ninja has no libqemu-x86_64-softmmu.dylib link target")

    block = [lines[start]]
    for line in lines[start + 1:]:
        if line and not line[0].isspace() and line.startswith(("build ", "rule ", "default ")):
            break
        block.append(line)

    link_edge = "\n".join(block)
    expected = "-Wl,-force_load," + runtime_path
    if expected not in link_edge:
        raise SystemExit(
            "QEMU link configuration is missing Apple's iOS compiler runtime. "
            "The Meson project-level link argument did not reach "
            "libqemu-x86_64-softmmu.dylib; refusing to compile with a known-broken link."
        )


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify_qemu_meson_link.py /path/to/build.ninja /path/to/libclang_rt.ios.a")
    ninja = Path(sys.argv[1])
    runtime = Path(sys.argv[2])
    if not ninja.is_file():
        raise SystemExit(f"QEMU Meson build file not found: {ninja}")
    if not runtime.is_file():
        raise SystemExit(f"Apple iOS compiler runtime not found: {runtime}")
    verify_link(ninja.read_text(encoding="utf-8"), str(runtime))
    print("Verified: QEMU's x86_64 system-emulator dylib link edge includes Apple's iOS compiler runtime.")


if __name__ == "__main__":
    main()
