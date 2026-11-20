#!/usr/bin/env python3
"""Patch QEMU's iOS Meson feature and link configuration before configure."""
from pathlib import Path
import os
import sys


def find_project_end(source: str) -> int:
    start = source.find("project(")
    if start < 0:
        raise SystemExit("QEMU meson.build: project() declaration not found")
    depth = 0
    quote = None
    escaped = False
    for index in range(start + len("project"), len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in ("'", '"'):
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index + 1
    raise SystemExit("QEMU meson.build: could not parse project() declaration")


def patch_source(source: str, runtime_path: str) -> str:
    old_probe = "config_host_data.set('CONFIG_POSIX_MEMALIGN', cc.has_function('posix_memalign', prefix: '#include <stdlib.h>'))"
    new_probe = "config_host_data.set('CONFIG_POSIX_MEMALIGN', true)"
    if new_probe not in source:
        if old_probe not in source:
            raise SystemExit("QEMU meson.build changed: POSIX_MEMALIGN feature probe not found")
        source = source.replace(old_probe, new_probe, 1)

    marker = "add_project_link_arguments('-Wl,-force_load,' + ios_compiler_rt, language: 'c')"
    if marker not in source:
        project_end = find_project_end(source)
        line_end = source.find("\n", project_end)
        if line_end < 0:
            line_end = project_end
        block = (
            "\n# i-Steam iOS: explicitly link Apple's iOS compiler runtime into QEMU C targets.\n"
            "ios_compiler_rt = run_command('sh', '-c', 'printf \"%s\" \"$IOS_COMPILER_RT\"', check: true).stdout().strip()\n"
            "if ios_compiler_rt == ''\n"
            "  error('IOS_COMPILER_RT is required for the i-Steam iOS build')\n"
            "endif\n"
            + marker + "\n"
        )
        source = source[:line_end + 1] + block + source[line_end + 1:]
    if new_probe not in source or marker not in source:
        raise SystemExit("QEMU meson.build patch verification failed")
    return source


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch_qemu_meson_ios.py /path/to/qemu/meson.build")
    runtime = os.environ.get("IOS_COMPILER_RT", "")
    if not runtime or not Path(runtime).is_file():
        raise SystemExit("IOS_COMPILER_RT must point to an existing libclang_rt.ios.a")
    path = Path(sys.argv[1])
    source = path.read_text(encoding="utf-8")
    patched = patch_source(source, runtime)
    path.write_text(patched, encoding="utf-8")
    print(f"Patched QEMU Meson configuration for iOS compiler runtime: {runtime}")


if __name__ == "__main__":
    main()
