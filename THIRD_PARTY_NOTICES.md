# Third-party notices

## UTM (reference implementation)

i-Steam's QEMU integration references and adapts lifecycle and launcher patterns from UTM:

- Project: https://github.com/utmapp/UTM
- Relevant reference files: `Services/UTMQemuSystem.m`, `Configuration/UTMQemuConfiguration+Arguments.swift`, and `QEMULauncher/Bootstrap.c`
- License for those UTM source files: Apache License 2.0
- Copyright notice: Copyright © 2020–2022 osy and UTM contributors.

The Apache License 2.0 text is available at https://www.apache.org/licenses/LICENSE-2.0. Adapted source retains an attribution comment in `iSteam/QEMUNativeBridge.c`.

## QEMU

QEMU is a separate upstream project: https://gitlab.com/qemu-project/qemu. Its project-level license is generally GNU GPL version 2 or later, with components and dependencies potentially carrying different licenses. Before shipping a QEMU build, record the exact source revision, applied UTM patches, configure options, linked dependencies, and all applicable notices. Do not assume this notice alone satisfies redistribution requirements for a compiled runtime.
